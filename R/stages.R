# Stage wrappers around the punkst command line tools. Each stage records its
# parameters and input identity in <workdir>/punkstR_manifest.rds and is
# skipped on re-run when its outputs exist and nothing has changed.

default_threads <- function() {
    n <- suppressWarnings(parallel::detectCores())
    if (is.na(n)) 1L else max(1L, min(8L, n))
}

file_identity <- function(paths) {
    info <- file.info(paths)
    data.frame(path = normalizePath(paths, mustWork = FALSE),
               size = info$size, mtime = as.numeric(info$mtime),
               stringsAsFactors = FALSE)
}

manifest_path <- function(workdir) file.path(workdir, "punkstR_manifest.rds")

read_manifest <- function(workdir) {
    p <- manifest_path(workdir)
    if (file.exists(p)) readRDS(p) else list()
}

# Run `run()` unless the manifest shows the stage is up to date.
run_stage <- function(workdir, name, params, inputs, outputs, run, overwrite) {
    dir.create(workdir, showWarnings = FALSE, recursive = TRUE)
    params$.inputs <- file_identity(inputs)
    man <- read_manifest(workdir)
    up_to_date <- !overwrite && all(file.exists(outputs)) &&
        isTRUE(all.equal(man[[name]], params, check.attributes = FALSE))
    if (up_to_date) {
        message("[punkstR] ", name, ": up to date, skipping")
    } else {
        message("[punkstR] ", name, ": running")
        t0 <- Sys.time()
        run()
        missing <- outputs[!file.exists(outputs)]
        if (length(missing))
            stop(name, " finished but did not produce: ",
                 paste(missing, collapse = ", "), call. = FALSE)
        man <- read_manifest(workdir)
        man[[name]] <- params
        saveRDS(man, manifest_path(workdir))
        message(sprintf("[punkstR] %s: done in %.0f s", name,
                        as.numeric(difftime(Sys.time(), t0, units = "secs"))))
    }
}

require_bin <- function(bin) {
    b <- resolve_bin(bin)
    if (is.na(b) || !file.exists(b))
        stop("punkst binary not found; see check_punkst_setup().", call. = FALSE)
    b
}

new_stage <- function(class, workdir, files, params)
    structure(list(workdir = workdir, files = files, params = params),
              class = c(class, "punkstStage"))

#' @export
print.punkstStage <- function(x, ...) {
    cat("<", class(x)[1], "> in ", x$workdir, "\n", sep = "")
    for (n in names(x$files)) cat(sprintf("  %-9s %s\n", n, x$files[[n]]))
    invisible(x)
}

#' Regular expression for Xenium control features
#'
#' Matches the control probes and codewords in Xenium transcript tables
#' (`antisense_*`, `NegControl*`, `BLANK_*`, `UnassignedCodeword*`). Pass it as
#' `exclude_feature_regex` to [punkst_topic_model()].
#' @return A character string.
#' @export
xenium_control_regex <- function() "^(antisense_|NegControl|BLANK_|UnassignedCodeword)"

#' Tile a transcript file (`punkst pts2tiles`)
#'
#' @param tsv Transcript file from [sdata_export()] (columns x, y, feature).
#' @param workdir Directory for outputs, logs and the manifest.
#' @param tile_size Tile size in the same units as the coordinates (microns).
#' @param threads Number of threads.
#' @param bin Path to `punkst`; see [punkst_setup()].
#' @param overwrite Re-run even if up to date.
#' @return A `punkstTiles` stage object with the output `files`.
#' @export
punkst_pts2tiles <- function(tsv, workdir, tile_size = 500,
                             threads = default_threads(), bin = NULL,
                             overwrite = FALSE) {
    if (!file.exists(tsv)) stop("Input not found: ", tsv, call. = FALSE)
    bin <- require_bin(bin)
    prefix <- file.path(workdir, "tiled")
    files <- list(tsv = paste0(prefix, ".tsv"), index = paste0(prefix, ".index"),
                  features = paste0(prefix, ".features.tsv"),
                  coord_range = paste0(prefix, ".coord_range.tsv"))
    params <- list(bin = bin, tile_size = tile_size)
    run_stage(workdir, "pts2tiles", params, tsv, unlist(files), overwrite = overwrite,
        run = function() run_tool(bin, c(
            "pts2tiles", "--in-tsv", tsv,
            "--icol-x", 0, "--icol-y", 1, "--icol-feature", 2,
            "--tile-size", tile_size, "--temp-dir", file.path(workdir, "tmp_pts2tiles"),
            "--threads", threads, "--out-prefix", prefix),
            file.path(workdir, "pts2tiles.log"), "punkst pts2tiles"))
    new_stage("punkstTiles", workdir, files, params)
}

#' Pool transcripts into hexagons (`punkst tiles2hex`)
#'
#' @param tiles A `punkstTiles` object from [punkst_pts2tiles()].
#' @param hex_grid_dist Centre-to-centre hexagon spacing (microns).
#' @param min_count Minimum transcripts for a hexagon to be kept.
#' @param seed Random seed for the hexagon order.
#' @inheritParams punkst_pts2tiles
#' @return A `punkstHex` stage object; `files$data` and `files$meta` feed
#'   [punkst_topic_model()].
#' @export
punkst_tiles2hex <- function(tiles, hex_grid_dist = 12, min_count = 20, seed = 1,
                             threads = default_threads(), bin = NULL,
                             overwrite = FALSE) {
    stopifnot(inherits(tiles, "punkstTiles"))
    bin <- require_bin(bin)
    workdir <- tiles$workdir
    stem <- file.path(workdir, sprintf("hex_%s", format(hex_grid_dist)))
    files <- list(data = paste0(stem, ".txt"), meta = paste0(stem, ".json"))
    params <- list(bin = bin, hex_grid_dist = hex_grid_dist,
                   min_count = min_count, seed = seed)
    run_stage(workdir, "tiles2hex", params,
        c(tiles$files$tsv, tiles$files$index, tiles$files$features),
        unlist(files), overwrite = overwrite,
        run = function() run_tool(bin, c(
            "tiles2hex", "--in-tsv", tiles$files$tsv, "--in-index", tiles$files$index,
            "--feature-dict", tiles$files$features,
            "--icol-x", 0, "--icol-y", 1, "--icol-feature", 2,
            "--hex-grid-dist", hex_grid_dist, "--min-count", min_count,
            "--out", files$data, "--randomize", "--seed", seed,
            "--temp-dir", file.path(workdir, "tmp_tiles2hex"), "--threads", threads),
            file.path(workdir, "tiles2hex.log"), "punkst tiles2hex"))
    new_stage("punkstHex", workdir, c(files, list(features = tiles$files$features)),
              params)
}

# Append "--flag value" (or a bare "--flag" for TRUE) to `args` when `value`
# is set and differs from punkst's own default; otherwise leave punkst to use
# its default.
opt_arg <- function(args, flag, value, default = NULL) {
    if (is.null(value) || (!is.null(default) && identical(value, default)))
        return(args)
    if (is.logical(value)) {
        if (isTRUE(value)) c(args, flag) else args
    } else c(args, flag, value)
}

#' Fit a topic model to hexagon data (`punkst topic-model`)
#'
#' Exposes the options of `punkst topic-model` that apply to hexagon input
#' (the 10X input options and `--dataset-id` are not applicable). Defaults are
#' punkst's own, taken from its source (`script/fit_lda.cpp`) and docs, and an
#' option is passed on the command line only when it differs from its default,
#' so punkst's behaviour is unchanged unless you ask for it. Options whose
#' default is "unset" (for example `alpha`, which punkst sets to `1/K`) are
#' `NULL`.
#'
#' One deliberate difference: punkst does not run the transform by default,
#' but the results file is what most users need, so `transform = TRUE` here.
#' Note also that punkst does not sort topics unless `sort_topics = TRUE`.
#'
#' @param hex A `punkstHex` object from [punkst_tiles2hex()]; it supplies
#'   `--in-data`, `--in-meta` and `--features`.
#' @param n_topics Number of topics (`--n-topics`). Required unless
#'   `model_prior` is given.
#' @param n_epochs Training passes over the data (`--n-epochs`).
#' @param out_prefix Output prefix; default `<workdir>/<hex stem>.k<n_topics>`.
#' @param seed Random seed (`--seed`). The default `-1` lets punkst draw a
#'   random seed, so runs are not reproducible unless you set one.
#' @param threads Threads (`--threads`); `0` lets punkst (TBB) choose.
#' @param minibatch_size Minibatch size (`--minibatch-size`).
#' @param min_count_train Minimum total count for a unit to be trained on
#'   (`--min-count-train`).
#' @param min_count_per_feature Minimum total count for a feature to be kept
#'   (`--min-count-per-feature`).
#' @param include_feature_regex,exclude_feature_regex Regular expressions
#'   selecting features (`--include-feature-regex`, `--exclude-feature-regex`);
#'   e.g. [xenium_control_regex()].
#' @param icol_weight 0-based column of per-feature weights in the feature file
#'   (`--icol-weight`); `-1` disables weighting.
#' @param default_weight Weight for model or prior features missing from the
#'   feature file (`--default-weight`); negative drops them.
#' @param modal Modality index (`--modal`).
#' @param kappa,tau0 Online learning decay rate and offset (`--kappa`,
#'   `--tau0`).
#' @param alpha,eta Document-topic and topic-word priors (`--alpha`, `--eta`);
#'   `NULL` uses `1/K`.
#' @param max_iter,mean_change_tol Per-document inference limits
#'   (`--max-iter`, `--mean-change-tol`).
#' @param reproducible_init Deterministic per-document initialisation, slower
#'   (`--reproducible-init`).
#' @param model_prior File with an initial model matrix for continued
#'   training (`--model-prior`).
#' @param prior_scale,prior_scale_rel Scaling of the prior model
#'   (`--prior-scale`, `--prior-scale-rel`; the relative one wins).
#' @param projection_only Transform with `model_prior` and do not train
#'   (`--projection-only`).
#' @param fit_background Fit a background component in addition to the topics
#'   (`--fit-background`).
#' @param background_prior File with a background prior vector
#'   (`--background-prior`).
#' @param background_init_scale,background_prevalence_power,fix_background,
#'   bg_fraction_prior_a0,bg_fraction_prior_b0,warm_start_epochs Background
#'   model settings (`--background-init-scale`, `--background-prevalence-power`,
#'   `--fix-background`, `--bg-fraction-prior-a0`, `--bg-fraction-prior-b0`,
#'   `--warm-start-epochs`).
#' @param adaptive_topics Treat `n_topics` as an upper bound, prune unused
#'   topics and refit (`--adaptive-topics`).
#' @param min_topic_mean,adaptive_refit_epochs Adaptive fitting settings
#'   (`--min-topic-mean`, `--adaptive-refit-epochs`).
#' @param transform Transform the data to topic space after fitting
#'   (`--transform`); needed for the results and pseudobulk files.
#' @param sort_topics Sort topics by weight (`--sort-topics`).
#' @param topk_only If set, write only the top-k topics per unit to the
#'   results file (`--topk-only`).
#' @param residuals,feature_residuals,feature_diagnostics_cheap,
#'   unit_diagnostics_similarity,pseudobulk_all_features Diagnostic and output
#'   options (flags of the same names).
#' @param count_cache,count_cache_memory_budget Repeated-pass count cache
#'   (`--count-cache`: `"off"`, `"on"`, `"auto"`; `--count-cache-memory-budget`
#'   with K, M or G suffixes).
#' @param temp_dir Parent directory for temporary files (`--temp-dir`); `NULL`
#'   uses the system temporary directory.
#' @param debug If > 0, process only this many units (`--debug`).
#' @param verbose Verbosity (`--verbose`).
#' @param bin Path to `punkst`; see [punkst_setup()].
#' @param overwrite Re-run even if the manifest shows the stage is up to date.
#' @return A `punkstModel` stage object. `files` holds `model` (features x
#'   topics) and `state` always, plus `results` (per-unit topic proportions)
#'   and `pseudobulk` when the transform ran, and `unit_stats` when
#'   `residuals` is on.
#' @export
punkst_topic_model <- function(hex, n_topics = NULL, n_epochs = 1L,
        out_prefix = NULL, seed = -1L, threads = 0L,
        minibatch_size = 512L, min_count_train = 20L, min_count_per_feature = 1L,
        include_feature_regex = NULL, exclude_feature_regex = NULL,
        icol_weight = -1L, default_weight = -1, modal = 0L,
        kappa = 0.7, tau0 = 10, alpha = NULL, eta = NULL,
        max_iter = 100L, mean_change_tol = 1e-3, reproducible_init = FALSE,
        model_prior = NULL, prior_scale = NULL, prior_scale_rel = NULL,
        projection_only = FALSE,
        fit_background = FALSE, background_prior = NULL,
        background_init_scale = 0.5, background_prevalence_power = 0,
        fix_background = FALSE, bg_fraction_prior_a0 = 2, bg_fraction_prior_b0 = 8,
        warm_start_epochs = 0.5,
        adaptive_topics = FALSE, min_topic_mean = 1e-5, adaptive_refit_epochs = 1L,
        transform = TRUE, sort_topics = FALSE, topk_only = NULL,
        residuals = FALSE, feature_residuals = FALSE,
        feature_diagnostics_cheap = FALSE, unit_diagnostics_similarity = FALSE,
        pseudobulk_all_features = FALSE,
        count_cache = "auto", count_cache_memory_budget = "1G",
        temp_dir = NULL, debug = 0L, verbose = 0L,
        bin = NULL, overwrite = FALSE) {
    stopifnot(inherits(hex, "punkstHex"))
    if (is.null(n_topics) && is.null(model_prior))
        stop("Give n_topics, or model_prior to start from an existing model.",
             call. = FALSE)
    if (isTRUE(projection_only) && is.null(model_prior))
        stop("projection_only requires model_prior.", call. = FALSE)
    if (!is.null(model_prior) && !file.exists(model_prior))
        stop("model_prior not found: ", model_prior, call. = FALSE)
    if (!is.null(background_prior) && !file.exists(background_prior))
        stop("background_prior not found: ", background_prior, call. = FALSE)
    bin <- require_bin(bin)
    workdir <- hex$workdir
    stem <- sub("\\.txt$", "", basename(hex$files$data))
    tag <- if (!is.null(n_topics)) sprintf("k%d", as.integer(n_topics)) else "prior"
    if (is.null(out_prefix)) out_prefix <- file.path(workdir, paste0(stem, ".", tag))

    with_transform <- isTRUE(transform) || isTRUE(projection_only)
    files <- list(model = paste0(out_prefix, ".model.tsv"),
                  state = paste0(out_prefix, ".state.tsv"))
    if (with_transform) {
        files$results <- paste0(out_prefix, ".results.tsv")
        files$pseudobulk <- paste0(out_prefix, ".pseudobulk.tsv")
    }
    if (isTRUE(residuals)) files$unit_stats <- paste0(out_prefix, ".unit_stats.tsv")

    # everything that can change the outcome, for the manifest
    params <- list(bin = bin, n_topics = n_topics, n_epochs = n_epochs, seed = seed,
        minibatch_size = minibatch_size, min_count_train = min_count_train,
        min_count_per_feature = min_count_per_feature,
        include_feature_regex = include_feature_regex,
        exclude_feature_regex = exclude_feature_regex, icol_weight = icol_weight,
        default_weight = default_weight, modal = modal, kappa = kappa, tau0 = tau0,
        alpha = alpha, eta = eta, max_iter = max_iter,
        mean_change_tol = mean_change_tol, reproducible_init = reproducible_init,
        model_prior = model_prior, prior_scale = prior_scale,
        prior_scale_rel = prior_scale_rel, projection_only = projection_only,
        fit_background = fit_background, background_prior = background_prior,
        background_init_scale = background_init_scale,
        background_prevalence_power = background_prevalence_power,
        fix_background = fix_background, bg_fraction_prior_a0 = bg_fraction_prior_a0,
        bg_fraction_prior_b0 = bg_fraction_prior_b0,
        warm_start_epochs = warm_start_epochs, adaptive_topics = adaptive_topics,
        min_topic_mean = min_topic_mean,
        adaptive_refit_epochs = adaptive_refit_epochs, transform = transform,
        sort_topics = sort_topics, topk_only = topk_only, residuals = residuals,
        feature_residuals = feature_residuals,
        feature_diagnostics_cheap = feature_diagnostics_cheap,
        unit_diagnostics_similarity = unit_diagnostics_similarity,
        pseudobulk_all_features = pseudobulk_all_features,
        count_cache = count_cache,
        count_cache_memory_budget = count_cache_memory_budget)

    a <- c("topic-model", "--in-data", hex$files$data, "--in-meta", hex$files$meta,
           "--features", hex$files$features, "--out-prefix", out_prefix)
    a <- opt_arg(a, "--n-topics", n_topics)
    a <- opt_arg(a, "--n-epochs", n_epochs, 1L)
    a <- opt_arg(a, "--seed", seed, -1L)
    a <- opt_arg(a, "--threads", threads, 0L)
    a <- opt_arg(a, "--minibatch-size", minibatch_size, 512L)
    a <- opt_arg(a, "--min-count-train", min_count_train, 20L)
    a <- opt_arg(a, "--min-count-per-feature", min_count_per_feature, 1L)
    a <- opt_arg(a, "--include-feature-regex", include_feature_regex)
    a <- opt_arg(a, "--exclude-feature-regex", exclude_feature_regex)
    a <- opt_arg(a, "--icol-weight", icol_weight, -1L)
    a <- opt_arg(a, "--default-weight", default_weight, -1)
    a <- opt_arg(a, "--modal", modal, 0L)
    a <- opt_arg(a, "--kappa", kappa, 0.7)
    a <- opt_arg(a, "--tau0", tau0, 10)
    a <- opt_arg(a, "--alpha", alpha)
    a <- opt_arg(a, "--eta", eta)
    a <- opt_arg(a, "--max-iter", max_iter, 100L)
    a <- opt_arg(a, "--mean-change-tol", mean_change_tol, 1e-3)
    a <- opt_arg(a, "--reproducible-init", reproducible_init)
    a <- opt_arg(a, "--model-prior", model_prior)
    a <- opt_arg(a, "--prior-scale", prior_scale)
    a <- opt_arg(a, "--prior-scale-rel", prior_scale_rel)
    a <- opt_arg(a, "--projection-only", projection_only)
    a <- opt_arg(a, "--fit-background", fit_background)
    a <- opt_arg(a, "--background-prior", background_prior)
    a <- opt_arg(a, "--background-init-scale", background_init_scale, 0.5)
    a <- opt_arg(a, "--background-prevalence-power", background_prevalence_power, 0)
    a <- opt_arg(a, "--fix-background", fix_background)
    a <- opt_arg(a, "--bg-fraction-prior-a0", bg_fraction_prior_a0, 2)
    a <- opt_arg(a, "--bg-fraction-prior-b0", bg_fraction_prior_b0, 8)
    a <- opt_arg(a, "--warm-start-epochs", warm_start_epochs, 0.5)
    a <- opt_arg(a, "--adaptive-topics", adaptive_topics)
    a <- opt_arg(a, "--min-topic-mean", min_topic_mean, 1e-5)
    a <- opt_arg(a, "--adaptive-refit-epochs", adaptive_refit_epochs, 1L)
    a <- opt_arg(a, "--transform", transform)
    a <- opt_arg(a, "--sort-topics", sort_topics)
    a <- opt_arg(a, "--topk-only", topk_only)
    a <- opt_arg(a, "--residuals", residuals)
    a <- opt_arg(a, "--feature-residuals", feature_residuals)
    a <- opt_arg(a, "--feature-diagnostics-cheap", feature_diagnostics_cheap)
    a <- opt_arg(a, "--unit-diagnostics-similarity", unit_diagnostics_similarity)
    a <- opt_arg(a, "--pseudobulk-all-features", pseudobulk_all_features)
    a <- opt_arg(a, "--count-cache", count_cache, "auto")
    a <- opt_arg(a, "--count-cache-memory-budget", count_cache_memory_budget, "1G")
    a <- opt_arg(a, "--temp-dir", temp_dir)
    a <- opt_arg(a, "--debug", debug, 0L)
    a <- opt_arg(a, "--verbose", verbose, 0L)

    name <- paste0("topic_model_", basename(out_prefix))
    run_stage(workdir, name, params,
        c(hex$files$data, hex$files$meta, model_prior, background_prior),
        unlist(files), overwrite = overwrite,
        run = function() run_tool(bin, a, file.path(workdir, paste0(name, ".log")),
                                  "punkst topic-model"))
    new_stage("punkstModel", workdir, files, params)
}

#' Run the whole pipeline from a SpatialData store
#'
#' Chains [sdata_export()], [punkst_pts2tiles()], [punkst_tiles2hex()] and
#' [punkst_topic_model()] in `workdir`. Finished stages are skipped on re-run.
#'
#' @param sdata Path to the SpatialData `.zarr` store.
#' @param workdir Directory for all outputs.
#' @param export A list of extra arguments for [sdata_export()].
#' @param tile_size,hex_grid_dist,min_count,n_topics,seed,threads
#'   See the individual stage functions.
#' @param topic_model A list of further arguments for [punkst_topic_model()],
#'   e.g. `list(n_epochs = 2, exclude_feature_regex = xenium_control_regex())`.
#' @param bin,python See [punkst_setup()].
#' @param overwrite Re-run all stages.
#' @return A `punkstRun` object with elements `transcripts`, `tiles`, `hex`
#'   and `model`.
#' @export
run_punkst_pipeline <- function(sdata, workdir, export = list(),
                                tile_size = 500, hex_grid_dist = 12,
                                min_count = 20, n_topics, topic_model = list(),
                                seed = 1, threads = default_threads(),
                                bin = NULL, python = NULL, overwrite = FALSE) {
    chk <- check_punkst_setup(bin = bin, python = python, quiet = TRUE)
    if (!chk$bin_ok || !chk$python_ok) {
        print(chk)
        stop("Setup check failed; see above.", call. = FALSE)
    }
    dir.create(workdir, showWarnings = FALSE, recursive = TRUE)
    tsv <- file.path(workdir, "transcripts.tsv")
    do.call(sdata_export, c(list(sdata = sdata, out = tsv, python = python,
                                 overwrite = overwrite), export))
    tiles <- punkst_pts2tiles(tsv, workdir, tile_size, threads, bin, overwrite)
    hex <- punkst_tiles2hex(tiles, hex_grid_dist, min_count, seed, threads, bin,
                            overwrite)
    tm_args <- utils::modifyList(
        list(seed = seed, threads = threads), topic_model)
    model <- do.call(punkst_topic_model,
                     c(list(hex = hex, n_topics = n_topics, bin = bin,
                            overwrite = overwrite), tm_args))
    structure(list(transcripts = tsv, tiles = tiles, hex = hex, model = model),
              class = "punkstRun")
}

#' @export
print.punkstRun <- function(x, ...) {
    cat("<punkstRun>\n")
    cat("  transcripts:", x$transcripts, "\n")
    for (s in c("tiles", "hex", "model")) print(x[[s]])
    invisible(x)
}
