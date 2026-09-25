#' Export a SpatialData points element to punkst transcript format
#'
#' Runs the bundled `spatialdata_to_punkst.py` with `system2()`; no Python
#' module is loaded into R. The output is a tab-separated file with a
#' `#`-prefixed header and columns `x`, `y`, `feature`, ready for
#' `punkst pts2tiles`.
#'
#' For Xenium stores written by `spatialdata-io`, the stored coordinates are
#' microns while the registered `global` coordinate system is image pixels, so
#' the default `coordinate_system = "intrinsic"` exports microns as punkst
#' expects.
#'
#' @param sdata Path to the SpatialData `.zarr` store.
#' @param out Output path (`.tsv` or `.tsv.gz`).
#' @param points_key Name of the points element.
#' @param coordinate_system Coordinate system to export in, or `"intrinsic"`
#'   for the stored coordinates. `NULL` lets the script infer it when only one
#'   is registered.
#' @param min_qv Drop rows with quality below this value (e.g. 20 for Xenium).
#' @param qv_column Name of the quality column.
#' @param feature_column Feature column; default is the element's feature key.
#' @param overwrite Re-export if `out` already exists.
#' @param python Interpreter override; see [punkst_setup()].
#' @param log Log file for the script's output.
#' @return The output path, invisibly.
#' @export
sdata_export <- function(sdata, out, points_key = "transcripts",
                         coordinate_system = "intrinsic", min_qv = NULL,
                         qv_column = "qv", feature_column = NULL,
                         overwrite = FALSE, python = NULL,
                         log = paste0(out, ".export.log")) {
    if (!dir.exists(sdata))
        stop("SpatialData store not found: ", sdata, call. = FALSE)
    if (file.exists(out) && !overwrite) {
        message("Output exists, skipping export (overwrite = TRUE to redo): ", out)
        return(invisible(out))
    }
    py <- resolve_python(python)
    if (is.na(py) || !file.exists(py))
        stop("No Python interpreter found; see check_punkst_setup().", call. = FALSE)
    script <- system.file("python", "spatialdata_to_punkst.py", package = "punkstR")
    if (!nzchar(script)) stop("Bundled export script not found.", call. = FALSE)

    args <- c(script, "--sdata", sdata, "--points-key", points_key, "--out", out)
    if (!is.null(coordinate_system))
        args <- c(args, "--coordinate-system", coordinate_system)
    if (!is.null(min_qv))
        args <- c(args, "--min-qv", min_qv, "--qv-column", qv_column)
    if (!is.null(feature_column))
        args <- c(args, "--feature-column", feature_column)

    dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
    run_tool(py, args, log, what = "spatialdata_to_punkst.py")
    if (!file.exists(out))
        stop("Export finished but produced no output file: ", out, call. = FALSE)
    invisible(out)
}
