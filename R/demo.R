#' Create a small synthetic SpatialData store
#'
#' Writes a store with one Points element, `transcripts`, of 20 genes in two
#' spatial regions: the left half is enriched for genes `A0`-`A9`, the right
#' half for `B0`-`B9`. A two-topic model has real structure to recover, which
#' makes it a fast fixture for the vignette and for trying the pipeline
#' (seconds, a few MB). Coordinates live in one identity-registered coordinate
#' system, `global`.
#'
#' @param out Path of the `.zarr` store to create.
#' @param n_points Number of transcripts.
#' @param size Side length of the square field.
#' @param n_genes Number of genes (half `A*`, half `B*`).
#' @param seed Random seed.
#' @param overwrite Replace `out` if it exists.
#' @param python Interpreter override; see [punkst_setup()].
#' @param log Log file.
#' @return `out`, invisibly.
#' @export
sdata_demo <- function(out, n_points = 60000L, size = 200, n_genes = 20L, seed = 0L,
                       overwrite = FALSE, python = NULL,
                       log = tempfile("sdata_demo", fileext = ".log")) {
    if (file.exists(out) && !overwrite)
        stop("Store exists (overwrite = TRUE to replace): ", out, call. = FALSE)
    py <- resolve_python(python)
    if (is.na(py) || !file.exists(py))
        stop("No Python interpreter found; see check_punkst_setup().", call. = FALSE)
    script <- system.file("python", "make_synthetic_sdata.py", package = "punkstR")
    if (!nzchar(script)) stop("Bundled script not found.", call. = FALSE)
    code <- paste("import sys; sys.path.insert(0, sys.argv[1]); import make_synthetic_sdata as m;",
                  "m.build_structured(sys.argv[2], n_points=int(sys.argv[3]),",
                  "size=float(sys.argv[4]), n_genes=int(sys.argv[5]), seed=int(sys.argv[6]))")
    run_tool(py, c("-c", code, dirname(script), out, as.integer(n_points),
                   format(size), as.integer(n_genes), as.integer(seed)),
             log, what = "make_synthetic_sdata.py")
    invisible(out)
}
