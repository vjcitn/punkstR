#' Summarise a SpatialData store
#'
#' Runs the bundled `sdata_info.py` with `system2()` and reads the JSON it
#' writes. Useful for checking which coordinate system holds microns before
#' exporting.
#'
#' @param sdata Path to the SpatialData `.zarr` store.
#' @param points_key Points element for which row count and coordinate extent
#'   are computed (this can take a while for large stores). `NULL` computes it
#'   for every points element.
#' @param python Interpreter override; see [punkst_setup()].
#' @param log Log file for the script's output.
#' @return A list with `points` (per element: `columns`, `attrs`, `rows`,
#'   `max_x`, `max_y`, `transformations`), `images` (pixel sizes at full
#'   resolution), `shapes`, `tables` and `spatialdata_version`.
#' @export
sdata_info <- function(sdata, points_key = "transcripts", python = NULL,
                       log = tempfile("sdata_info", fileext = ".log")) {
    if (!dir.exists(sdata))
        stop("SpatialData store not found: ", sdata, call. = FALSE)
    py <- resolve_python(python)
    if (is.na(py) || !file.exists(py))
        stop("No Python interpreter found; see check_punkst_setup().", call. = FALSE)
    script <- system.file("python", "sdata_info.py", package = "punkstR")
    if (!nzchar(script)) stop("Bundled script not found.", call. = FALSE)
    out <- tempfile(fileext = ".json")
    on.exit(unlink(out))
    args <- c(script, "--sdata", sdata, "--out", out)
    if (!is.null(points_key)) args <- c(args, "--points-key", points_key)
    run_tool(py, args, log, what = "sdata_info.py")
    jsonlite::read_json(out, simplifyVector = FALSE)
}

#' Resolve a file from a stage object or a path
#'
#' @param x A stage object with a `files` list, or a single path.
#' @param what Class name used in the error message.
#' @param name Element of `x$files` to return.
#' @return A file path.
#' @noRd
stage_file <- function(x, what, name) {
    if (is.character(x) && length(x) == 1L) return(x)
    f <- x$files[[name]]
    if (is.null(f))
        stop("This object has no '", name, "' file; expected a ", what,
             " or a path.", call. = FALSE)
    f
}

#' Read the fitted gene x topic matrix
#'
#' @param model A `punkstModel` from [punkst_topic_model()], or the path to a
#'   `*.model.tsv` file.
#' @return A numeric matrix with genes in rows and topics in columns (column
#'   names are the topic indices as written by punkst). Entries are the
#'   pseudo-counts of each gene assigned to each topic.
#' @export
punkst_read_model <- function(model) {
    f <- stage_file(model, "punkstModel", "model")
    d <- utils::read.delim(f, check.names = FALSE, stringsAsFactors = FALSE)
    m <- as.matrix(d[, -1L, drop = FALSE])
    rownames(m) <- d[[1L]]
    m
}

#' Read per-hexagon topic probabilities
#'
#' @param model A `punkstModel` fitted with `transform = TRUE`, or the path to
#'   a `*.results.tsv` file.
#' @return A data frame with columns `key`, `x`, `y` and one column per topic
#'   (named as written by punkst). The keys are random and not unique; match
#'   hexagons by position with [match_xy()].
#' @export
punkst_read_topics <- function(model) {
    f <- stage_file(model, "punkstModel", "results")
    n <- length(strsplit(readLines(f, n = 1L, warn = FALSE), "\t", fixed = TRUE)[[1L]])
    d <- utils::read.delim(f, check.names = FALSE, stringsAsFactors = FALSE,
                           colClasses = c("character", rep("numeric", n - 1L)))
    names(d)[1L] <- "key"
    d
}

#' Read the hexagon x gene count matrix
#'
#' Parses the sparse text file written by [punkst_tiles2hex()].
#'
#' @param hex A `punkstHex` object, or the path to the `hex_*.txt` file (the
#'   `.json` beside it is read for the gene dictionary).
#' @return A list with `units`, a data frame of `key`, `x`, `y`, `nfeat`,
#'   `total` per hexagon, and `counts`, a sparse `dgCMatrix` (hexagons x
#'   genes) with gene names as column names.
#' @export
punkst_read_hex <- function(hex) {
    f <- stage_file(hex, "punkstHex", "data")
    meta <- if (is.character(hex)) sub("\\.txt$", ".json", hex) else hex$files$meta
    dict <- jsonlite::read_json(meta, simplifyVector = FALSE)$dictionary
    genes <- character(length(dict))
    genes[unlist(dict) + 1L] <- names(dict)
    fields <- strsplit(readLines(f, warn = FALSE), "\t", fixed = TRUE)
    units <- data.frame(
        key = vapply(fields, `[`, "", 1L),
        x = as.numeric(vapply(fields, `[`, "", 2L)),
        y = as.numeric(vapply(fields, `[`, "", 3L)),
        nfeat = as.integer(vapply(fields, `[`, "", 4L)),
        total = as.integer(vapply(fields, `[`, "", 5L)))
    pairs <- unlist(lapply(fields, function(z) z[-(1:5)]), use.names = FALSE)
    n <- lengths(fields) - 5L
    counts <- Matrix::sparseMatrix(
        i = rep.int(seq_along(n), n),
        j = as.integer(sub(" .*", "", pairs)) + 1L,
        x = as.numeric(sub(".* ", "", pairs)),
        dims = c(length(n), length(genes)),
        dimnames = list(NULL, genes))
    list(units = units, counts = counts)
}

#' Read the feature table written by pts2tiles
#'
#' @param tiles A `punkstTiles` object, or the path to `tiled.features.tsv`.
#' @return A data frame with `feature` and `count`.
#' @export
punkst_read_features <- function(tiles) {
    f <- stage_file(tiles, "punkstTiles", "features")
    d <- utils::read.delim(f, header = FALSE, stringsAsFactors = FALSE,
                           col.names = c("feature", "count"))
    d
}

#' Match hexagons between two tables by their centre coordinates
#'
#' The random keys in punkst's outputs are not unique, so hexagons in the
#' results file and the count file are matched on their (x, y) centres.
#'
#' @param x,y Coordinates to look up.
#' @param ref_x,ref_y Reference coordinates, which must be unique.
#' @param digits Decimal places used when comparing coordinates.
#' @return An integer vector, for each `(x, y)` the index into the reference,
#'   or `NA` if not found.
#' @export
match_xy <- function(x, y, ref_x, ref_y, digits = 3L) {
    k <- function(a, b) paste(formatC(round(a, digits), format = "f", digits = digits),
                              formatC(round(b, digits), format = "f", digits = digits))
    rk <- k(ref_x, ref_y)
    if (anyDuplicated(rk)) stop("Reference hexagon centres are not unique.", call. = FALSE)
    match(k(x, y), rk)
}
