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
#' Splits a delimited point file into spatial tiles and writes an index. Covers
#' the standard mode of `punkst pts2tiles`; the `--tile-op-factor-tsv` mode
#' (converting factor-probability output, with `--binary-out`, `--K`,
#' `--pixel-res`, `--feature-dict`) is not wrapped. Defaults are punkst's own,
#' and an option is passed only when it differs from its default, except that
#' the column indices default to 0, 1 and 2 (x, y, feature), the layout
#' written by [sdata_export()], where punkst has no default.
#'
#' @param tsv Input delimited file (`--in-tsv`), e.g. from [sdata_export()].
#' @param workdir Directory for outputs, logs and the manifest.
#' @param tile_size Tile size in the input's coordinate units (`--tile-size`).
#'   Required.
#' @param icol_x,icol_y,icol_feature 0-based columns of x, y and feature
#'   (`--icol-x`, `--icol-y`, `--icol-feature`). `icol_feature = NULL` omits
#'   the feature column and the feature dictionary output.
#' @param icol_z Optional 0-based z column (`--icol-z`).
#' @param icol_int Optional 0-based integer-value (count) columns
#'   (`--icol-int`).
#' @param csv Treat the input as CSV (`--csv`); punkst otherwise infers it from
#'   the file extension.
#' @param keep_quotes 0-based columns to keep quoted in CSV output
#'   (`--keep-quotes`).
#' @param skip Number of input lines to skip (`--skip`).
#' @param skip_last_is_header Treat the last skipped line as the header
#'   (`--skip-last-is-header`). Lines starting with `#` at the top are
#'   detected automatically, so this is not needed for [sdata_export()]
#'   output.
#' @param scale Uniform coordinate scale factor (`--scale`).
#' @param scale_x,scale_y,scale_z Per-axis scale factors that override `scale`
#'   (`--scale-x`, `--scale-y`, `--scale-z`).
#' @param digits Precision of rewritten coordinates when scaling is applied
#'   (`--digits`).
#' @param include_cols,exclude_cols 0-based columns to keep or drop in the
#'   tiled output (`--include-cols`, `--exclude-cols`; mutually exclusive). The
#'   column positions in the tiled file then differ from the input, so pass
#'   matching `icol_*` to [punkst_tiles2hex()].
#' @param tile_buffer Buffer lines per tile per thread (`--tile-buffer`).
#' @param batch_size Batch size in lines for gzipped or streamed input
#'   (`--batch-size`).
#' @param temp_dir Directory for temporary files (`--temp-dir`); default is
#'   `<workdir>/tmp_pts2tiles`.
#' @param threads Number of threads (`--threads`).
#' @param verbose,debug Verbosity and debug level (`--verbose`, `--debug`).
#' @param bin Path to `punkst`; see [punkst_setup()].
#' @param overwrite Re-run even if up to date.
#' @return A `punkstTiles` stage object with the output `files` (`tsv`,
#'   `index`, `coord_range`, and `features` when a feature column is given).
#' @export
punkst_pts2tiles <- function(tsv, workdir, tile_size,
        icol_x = 0L, icol_y = 1L, icol_feature = 2L, icol_z = NULL,
        icol_int = NULL, csv = FALSE, keep_quotes = NULL, skip = 0L,
        skip_last_is_header = FALSE, scale = 1, scale_x = NULL, scale_y = NULL,
        scale_z = NULL, digits = 2L, include_cols = NULL, exclude_cols = NULL,
        tile_buffer = 1000L, batch_size = 10000L, temp_dir = NULL,
        threads = 1L, verbose = 1000000L, debug = 0L, bin = NULL,
        overwrite = FALSE) {
    if (missing(tile_size)) stop("tile_size is required.", call. = FALSE)
    if (!file.exists(tsv)) stop("Input not found: ", tsv, call. = FALSE)
    if (!is.null(include_cols) && !is.null(exclude_cols))
        stop("include_cols and exclude_cols are mutually exclusive.", call. = FALSE)
    bin <- require_bin(bin)
    prefix <- file.path(workdir, "tiled")
    files <- list(tsv = paste0(prefix, ".tsv"), index = paste0(prefix, ".index"),
                  coord_range = paste0(prefix, ".coord_range.tsv"))
    if (!is.null(icol_feature)) files$features <- paste0(prefix, ".features.tsv")
    params <- list(bin = bin, tile_size = tile_size, icol_x = icol_x,
        icol_y = icol_y, icol_feature = icol_feature, icol_z = icol_z,
        icol_int = icol_int, csv = csv, keep_quotes = keep_quotes, skip = skip,
        skip_last_is_header = skip_last_is_header, scale = scale,
        scale_x = scale_x, scale_y = scale_y, scale_z = scale_z, digits = digits,
        include_cols = include_cols, exclude_cols = exclude_cols,
        tile_buffer = tile_buffer, batch_size = batch_size)
    if (is.null(temp_dir)) temp_dir <- file.path(workdir, "tmp_pts2tiles")
    a <- c("pts2tiles", "--in-tsv", tsv, "--tile-size", tile_size,
           "--out-prefix", prefix, "--temp-dir", temp_dir)
    a <- opt_arg(a, "--icol-x", icol_x)
    a <- opt_arg(a, "--icol-y", icol_y)
    a <- opt_arg(a, "--icol-feature", icol_feature)
    a <- opt_arg(a, "--icol-z", icol_z)
    a <- opt_arg(a, "--icol-int", icol_int)
    a <- opt_arg(a, "--csv", csv)
    a <- opt_arg(a, "--keep-quotes", keep_quotes)
    a <- opt_arg(a, "--skip", skip, 0L)
    a <- opt_arg(a, "--skip-last-is-header", skip_last_is_header)
    a <- opt_arg(a, "--scale", scale, 1)
    a <- opt_arg(a, "--scale-x", scale_x)
    a <- opt_arg(a, "--scale-y", scale_y)
    a <- opt_arg(a, "--scale-z", scale_z)
    a <- opt_arg(a, "--digits", digits, 2L)
    a <- opt_arg(a, "--include-cols", include_cols)
    a <- opt_arg(a, "--exclude-cols", exclude_cols)
    a <- opt_arg(a, "--tile-buffer", tile_buffer, 1000L)
    a <- opt_arg(a, "--batch-size", batch_size, 10000L)
    a <- opt_arg(a, "--threads", threads, 1L)
    a <- opt_arg(a, "--verbose", verbose, 1000000L)
    a <- opt_arg(a, "--debug", debug, 0L)
    run_stage(workdir, "pts2tiles", params, tsv, unlist(files), overwrite = overwrite,
        run = function() run_tool(bin, a, file.path(workdir, "pts2tiles.log"),
                                  "punkst pts2tiles"))
    new_stage("punkstTiles", workdir, files, params)
}

#' Pool transcripts into hexagons (`punkst tiles2hex`)
#'
#' Aggregates tiled points into hexagonal units (or 3D BCC units) and writes a
#' sparse count file plus JSON metadata. Defaults are punkst's own and an
#' option is passed only when it differs. Column indices default to those used
#' when tiling (`tiles$params`).
#'
#' Give exactly the grid you need: `hex_grid_dist` or `hex_size` for 2D, or
#' `bcc_grid_dist` or `bcc_size` (with `icol_z`) for 3D. punkst has no default
#' size.
#'
#' @param tiles A `punkstTiles` object from [punkst_pts2tiles()].
#' @param hex_grid_dist,hex_size Hexagon centre-to-centre distance
#'   (`--hex-grid-dist`) or side length (`--hex-size`).
#' @param bcc_grid_dist,bcc_size BCC lattice spacing (`--bcc-grid-dist`) or
#'   size (`--bcc-size`) for 3D aggregation.
#' @param icol_x,icol_y,icol_feature 0-based columns in the tiled file
#'   (`--icol-x`, `--icol-y`, `--icol-feature`); default to the values used in
#'   [punkst_pts2tiles()].
#' @param icol_z 0-based z column, which enables 3D aggregation (`--icol-z`).
#' @param icol_int 0-based integer-value columns (`--icol-int`).
#' @param feature_dict Feature name list for non-integer feature columns
#'   (`--feature-dict`); defaults to the tiling stage's feature file.
#' @param min_count Minimum count per integer column for a unit to be kept,
#'   combined with OR (`--min-count`); punkst's default keeps units with at
#'   least 1.
#' @param bounding_boxes Rectangular regions `(xmin ymin xmax ymax)*` to
#'   restrict to (`--bounding-boxes`).
#' @param anchor_files,radius,ignore_background Aggregate around anchor points
#'   instead of a grid (`--anchor-files`, `--radius`, `--ignore-background`).
#' @param idf_q,idf_power,idf_min,idf_max Parameters of the capped IDF feature
#'   weights (`--idf-q`, `--idf-power`, `--idf-min`, `--idf-max`).
#' @param randomize Randomise the output order (`--randomize`). punkst does not
#'   by default; online topic-model training generally benefits from it.
#' @param seed Seed for the randomised output keys (`--seed`); `-1` draws a
#'   random one.
#' @param sort_mem Memory for sorting with K, M or G units (`--sort-mem`).
#' @param use_internal_sort Use punkst's internal sort instead of the system
#'   `sort` (`--use-internal-sort`).
#' @param out_prefix Output stem; default `<workdir>/hex_<grid size>`.
#' @param temp_dir Directory for temporary files; default
#'   `<workdir>/tmp_tiles2hex`.
#' @param threads Number of threads (`--threads`).
#' @param verbose,debug Verbosity and debug level.
#' @param bin Path to `punkst`; see [punkst_setup()].
#' @param overwrite Re-run even if up to date.
#' @return A `punkstHex` stage object; `files$data`, `files$meta` and
#'   `files$features` feed [punkst_topic_model()].
#' @export
punkst_tiles2hex <- function(tiles, hex_grid_dist = NULL, hex_size = NULL,
        bcc_grid_dist = NULL, bcc_size = NULL,
        icol_x = tiles$params$icol_x, icol_y = tiles$params$icol_y,
        icol_feature = tiles$params$icol_feature, icol_z = NULL, icol_int = NULL,
        feature_dict = tiles$files$features, min_count = NULL,
        bounding_boxes = NULL, anchor_files = NULL, radius = NULL,
        ignore_background = FALSE, idf_q = 95, idf_power = 0.3, idf_min = 0.1,
        idf_max = 5, randomize = FALSE, seed = -1L, sort_mem = NULL,
        use_internal_sort = FALSE, out_prefix = NULL, temp_dir = NULL,
        threads = 1L, verbose = 1000000L, debug = 0L, bin = NULL,
        overwrite = FALSE) {
    stopifnot(inherits(tiles, "punkstTiles"))
    if (is.null(hex_grid_dist) && is.null(hex_size) &&
        is.null(bcc_grid_dist) && is.null(bcc_size))
        stop("Give one of hex_grid_dist, hex_size, bcc_grid_dist, bcc_size.",
             call. = FALSE)
    if (!is.null(anchor_files) && is.null(radius))
        stop("anchor_files requires radius.", call. = FALSE)
    bin <- require_bin(bin)
    workdir <- tiles$workdir
    if (is.null(out_prefix)) {
        size <- if (!is.null(hex_grid_dist)) paste0("hex_", format(hex_grid_dist))
                else if (!is.null(hex_size)) paste0("hexsize_", format(hex_size))
                else if (!is.null(bcc_grid_dist)) paste0("bcc_", format(bcc_grid_dist))
                else paste0("bccsize_", format(bcc_size))
        out_prefix <- file.path(workdir, size)
    }
    files <- list(data = paste0(out_prefix, ".txt"), meta = paste0(out_prefix, ".json"))
    params <- list(bin = bin, hex_grid_dist = hex_grid_dist, hex_size = hex_size,
        bcc_grid_dist = bcc_grid_dist, bcc_size = bcc_size, icol_x = icol_x,
        icol_y = icol_y, icol_feature = icol_feature, icol_z = icol_z,
        icol_int = icol_int, feature_dict = feature_dict, min_count = min_count,
        bounding_boxes = bounding_boxes, anchor_files = anchor_files,
        radius = radius, ignore_background = ignore_background, idf_q = idf_q,
        idf_power = idf_power, idf_min = idf_min, idf_max = idf_max,
        randomize = randomize, seed = seed, sort_mem = sort_mem,
        use_internal_sort = use_internal_sort)
    if (is.null(temp_dir)) temp_dir <- file.path(workdir, "tmp_tiles2hex")
    a <- c("tiles2hex", "--in-tsv", tiles$files$tsv, "--in-index", tiles$files$index,
           "--out", files$data, "--temp-dir", temp_dir)
    a <- opt_arg(a, "--icol-x", icol_x)
    a <- opt_arg(a, "--icol-y", icol_y)
    a <- opt_arg(a, "--icol-z", icol_z)
    a <- opt_arg(a, "--icol-feature", icol_feature)
    a <- opt_arg(a, "--feature-dict", feature_dict)
    a <- opt_arg(a, "--icol-int", icol_int)
    a <- opt_arg(a, "--hex-grid-dist", hex_grid_dist)
    a <- opt_arg(a, "--hex-size", hex_size)
    a <- opt_arg(a, "--bcc-grid-dist", bcc_grid_dist)
    a <- opt_arg(a, "--bcc-size", bcc_size)
    a <- opt_arg(a, "--min-count", min_count)
    a <- opt_arg(a, "--bounding-boxes", bounding_boxes)
    a <- opt_arg(a, "--anchor-files", anchor_files)
    a <- opt_arg(a, "--radius", radius)
    a <- opt_arg(a, "--ignore-background", ignore_background)
    a <- opt_arg(a, "--idf-q", idf_q, 95)
    a <- opt_arg(a, "--idf-power", idf_power, 0.3)
    a <- opt_arg(a, "--idf-min", idf_min, 0.1)
    a <- opt_arg(a, "--idf-max", idf_max, 5)
    a <- opt_arg(a, "--randomize", randomize)
    a <- opt_arg(a, "--seed", seed, -1L)
    a <- opt_arg(a, "--sort-mem", sort_mem)
    a <- opt_arg(a, "--use-internal-sort", use_internal_sort)
    a <- opt_arg(a, "--threads", threads, 1L)
    a <- opt_arg(a, "--verbose", verbose, 1000000L)
    a <- opt_arg(a, "--debug", debug, 0L)
    name <- paste0("tiles2hex_", basename(out_prefix))
    run_stage(workdir, name, params,
        c(tiles$files$tsv, tiles$files$index, feature_dict, anchor_files),
        unlist(files), overwrite = overwrite,
        run = function() run_tool(bin, a, file.path(workdir, paste0(name, ".log")),
                                  "punkst tiles2hex"))
    new_stage("punkstHex", workdir,
              c(files, if (!is.null(feature_dict)) list(features = feature_dict)),
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
#' @param background_init_scale,background_prevalence_power,fix_background,bg_fraction_prior_a0,bg_fraction_prior_b0,warm_start_epochs Background
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
#' @param residuals,feature_residuals,feature_diagnostics_cheap,unit_diagnostics_similarity,pseudobulk_all_features Diagnostic and output
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
#' Each stage takes its options as a list, so every option of the stage
#' functions is reachable. The pipeline sets these defaults, which override the
#' stage functions' punkst defaults and are themselves overridden by your
#' lists: `tile_size = 500`; `hex_grid_dist = 12`, `min_count = 20`,
#' `randomize = TRUE`, `seed = 1`; `n_topics = 12`, `seed = 1`. `threads`
#' applies to all three punkst stages.
#'
#' @param sdata Path to the SpatialData `.zarr` store.
#' @param workdir Directory for all outputs.
#' @param export,pts2tiles,tiles2hex,topic_model Named lists of arguments for
#'   [sdata_export()], [punkst_pts2tiles()], [punkst_tiles2hex()] and
#'   [punkst_topic_model()], e.g.
#'   `topic_model = list(n_topics = 8, exclude_feature_regex = xenium_control_regex())`.
#' @param threads Threads for the punkst stages.
#' @param bin,python See [punkst_setup()].
#' @param overwrite Re-run all stages.
#' @return A `punkstRun` object with elements `transcripts`, `tiles`, `hex`
#'   and `model`.
#' @export
run_punkst_pipeline <- function(sdata, workdir, export = list(),
        pts2tiles = list(), tiles2hex = list(), topic_model = list(),
        threads = default_threads(), bin = NULL, python = NULL,
        overwrite = FALSE) {
    chk <- check_punkst_setup(bin = bin, python = python, quiet = TRUE)
    if (!chk$bin_ok || !chk$python_ok) {
        print(chk)
        stop("Setup check failed; see above.", call. = FALSE)
    }
    dir.create(workdir, showWarnings = FALSE, recursive = TRUE)
    tsv <- file.path(workdir, "transcripts.tsv")
    do.call(sdata_export, c(list(sdata = sdata, out = tsv, python = python,
                                 overwrite = overwrite), export))
    # pipeline-level defaults, each overridable through the argument lists
    p2t <- utils::modifyList(list(tile_size = 500, threads = threads), pts2tiles)
    tiles <- do.call(punkst_pts2tiles, c(list(tsv = tsv, workdir = workdir, bin = bin,
                                              overwrite = overwrite), p2t))
    t2h <- utils::modifyList(list(hex_grid_dist = 12, min_count = 20, randomize = TRUE,
                                  seed = 1, threads = threads), tiles2hex)
    hex <- do.call(punkst_tiles2hex, c(list(tiles = tiles, bin = bin,
                                            overwrite = overwrite), t2h))
    tm <- utils::modifyList(list(n_topics = 12, seed = 1, threads = threads),
                            topic_model)
    model <- do.call(punkst_topic_model, c(list(hex = hex, bin = bin,
                                                overwrite = overwrite), tm))
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
