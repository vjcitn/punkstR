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

#' Fit a topic model to hexagon data (`punkst topic-model`)
#'
#' @param hex A `punkstHex` object from [punkst_tiles2hex()].
#' @param n_topics Number of topics.
#' @param n_epochs Number of training epochs.
#' @param exclude_feature_regex Regular expression of features to leave out,
#'   e.g. [xenium_control_regex()]. `NULL` keeps all features.
#' @param min_count_per_feature,min_count_train Optional filters; `NULL` uses
#'   the punkst defaults.
#' @param seed Random seed.
#' @inheritParams punkst_pts2tiles
#' @return A `punkstModel` stage object with `files$model` (genes x topics),
#'   `files$results` (per-hexagon topic probabilities) and others.
#' @export
punkst_topic_model <- function(hex, n_topics = 12, n_epochs = 2,
                               exclude_feature_regex = NULL,
                               min_count_per_feature = NULL,
                               min_count_train = NULL, seed = 1,
                               threads = default_threads(), bin = NULL,
                               overwrite = FALSE) {
    stopifnot(inherits(hex, "punkstHex"))
    bin <- require_bin(bin)
    workdir <- hex$workdir
    prefix <- file.path(workdir, sprintf("%s.k%d",
        sub("\\.txt$", "", basename(hex$files$data)), as.integer(n_topics)))
    files <- list(model = paste0(prefix, ".model.tsv"),
                  results = paste0(prefix, ".results.tsv"),
                  pseudobulk = paste0(prefix, ".pseudobulk.tsv"))
    params <- list(bin = bin, n_topics = n_topics, n_epochs = n_epochs,
                   exclude_feature_regex = exclude_feature_regex,
                   min_count_per_feature = min_count_per_feature,
                   min_count_train = min_count_train, seed = seed)
    args <- c("topic-model", "--in-data", hex$files$data, "--in-meta", hex$files$meta,
              "--features", hex$files$features,
              "--n-topics", n_topics, "--n-epochs", n_epochs, "--sort-topics",
              if (!is.null(min_count_per_feature))
                  c("--min-count-per-feature", min_count_per_feature),
              if (!is.null(min_count_train)) c("--min-count-train", min_count_train),
              if (!is.null(exclude_feature_regex))
                  c("--exclude-feature-regex", exclude_feature_regex),
              "--out-prefix", prefix, "--transform",
              "--threads", threads, "--seed", seed)
    run_stage(workdir, sprintf("topic_model_k%d", as.integer(n_topics)), params,
        c(hex$files$data, hex$files$meta), unlist(files), overwrite = overwrite,
        run = function() run_tool(bin, args,
            file.path(workdir, sprintf("topic_model_k%d.log", as.integer(n_topics))),
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
#' @param tile_size,hex_grid_dist,min_count,n_topics,n_epochs,
#'   exclude_feature_regex,min_count_per_feature,min_count_train,seed,threads
#'   See the individual stage functions.
#' @param bin,python See [punkst_setup()].
#' @param overwrite Re-run all stages.
#' @return A `punkstRun` object with elements `transcripts`, `tiles`, `hex`
#'   and `model`.
#' @export
run_punkst_pipeline <- function(sdata, workdir, export = list(),
                                tile_size = 500, hex_grid_dist = 12,
                                min_count = 20, n_topics = 12, n_epochs = 2,
                                exclude_feature_regex = NULL,
                                min_count_per_feature = NULL,
                                min_count_train = NULL, seed = 1,
                                threads = default_threads(), bin = NULL,
                                python = NULL, overwrite = FALSE) {
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
    model <- punkst_topic_model(hex, n_topics, n_epochs, exclude_feature_regex,
                                min_count_per_feature, min_count_train, seed,
                                threads, bin, overwrite)
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
