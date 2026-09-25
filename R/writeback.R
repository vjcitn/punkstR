#' Write punkst results back into a SpatialData store
#'
#' Adds one *run* to a SpatialData store: a `shapes` element of circles at the
#' hexagon centres (`punkst_<run>_hexagons`) and a `table` (`punkst_<run>`)
#' holding the hexagon x gene counts, the per-hexagon topic probabilities
#' (`obsm["topics"]`), the gene x topic loadings (`varm["loadings"]`) and the
#' parameters that produced them (`uns["punkst"]`). The table is linked to the
#' shapes through `region`/`instance_id`.
#'
#' Because element names carry the run name, any number of runs -- different
#' topic counts, hexagon sizes, seeds, priors -- can coexist in one store and be
#' compared with [sdata_runs()] and [punkst_compare_runs()]. Writing a run name
#' that already exists is an error unless `overwrite = TRUE`.
#'
#' By default results go to a **new sidecar store** (`out`), which holds only
#' the punkst elements and is read alongside the original. With
#' `in_place = TRUE` they are added to the store the analysis started from
#' (this modifies it; the original elements are left untouched).
#'
#' The hexagon shapes inherit the transformations of the source Points element
#' when the export used `coordinate_system = "intrinsic"` (so, for Xenium, the
#' micron-to-pixel scale is preserved and the hexagons overlay the images and
#' transcripts). If the export used a named coordinate system the shapes are
#' registered in that system with an identity transformation.
#'
#' @param run A `punkstRun` from [run_punkst_pipeline()], or a `punkstModel`
#'   from [punkst_topic_model()] (then also give `hex` and `sdata`).
#' @param hex A `punkstHex`; taken from `run` when that is a `punkstRun`.
#' @param sdata The original store; taken from `run` when possible.
#' @param out Path of the sidecar store to create or extend. Default
#'   `<sdata minus .zarr>_punkst.zarr`. Ignored when `in_place = TRUE`.
#' @param in_place Write into `sdata` itself instead of a sidecar store.
#' @param name Run name used in element names. Default: the model output stem
#'   (e.g. `hex_12.k12`), which already encodes hexagon spacing and topic
#'   count; pass your own (e.g. `"k12_alpha0.1"`) when tuning other settings.
#' @param points_key Points element whose transformations the hexagons inherit;
#'   taken from `run` when possible.
#' @param coordinate_system Coordinate system used for the export (see
#'   [sdata_export()]); `"intrinsic"` (default), a name, or `NULL` for the
#'   element's only system; taken from `run` when possible.
#' @param overwrite Replace an existing run of the same name.
#' @param python Interpreter override; see [punkst_setup()].
#' @param log Log file.
#' @return The path of the store written to (invisibly), with attributes
#'   `run`, `shapes`, `table`.
#' @export
sdata_writeback <- function(run, hex = NULL, sdata = NULL, out = NULL,
                            in_place = FALSE, name = NULL, points_key = NULL,
                            coordinate_system = "intrinsic", overwrite = FALSE,
                            python = NULL, log = tempfile("writeback", fileext = ".log")) {
    if (inherits(run, "punkstRun")) {
        model <- run$model
        if (is.null(hex)) hex <- run$hex
        if (is.null(sdata)) sdata <- run$source$sdata
        if (is.null(points_key)) points_key <- run$source$points_key
        if (missing(coordinate_system)) coordinate_system <- run$source["coordinate_system"][[1]]
    } else model <- run
    if (!inherits(model, "punkstModel") || !inherits(hex, "punkstHex"))
        stop("Give a punkstRun, or a punkstModel together with its punkstHex.", call. = FALSE)
    if (is.null(model$files$results))
        stop("The model has no results file; refit with transform = TRUE.", call. = FALSE)
    if (is.null(sdata) || !dir.exists(sdata))
        stop("Original SpatialData store not found; pass `sdata`.", call. = FALSE)
    if (is.null(points_key)) points_key <- "transcripts"
    if (is.null(name)) name <- basename(sub("\\.model\\.tsv$", "", model$files$model))
    name <- gsub("[^A-Za-z0-9_]", "_", name)
    target <- if (in_place) sdata else
        if (is.null(out)) paste0(sub("/+$", "", sub("\\.zarr/*$", "", sdata)), "_punkst.zarr") else out
    py <- resolve_python(python)
    if (is.na(py) || !file.exists(py))
        stop("No Python interpreter found; see check_punkst_setup().", call. = FALSE)
    script <- system.file("python", "punkst_to_sdata.py", package = "punkstR")
    if (!nzchar(script)) stop("Bundled script not found.", call. = FALSE)

    pf <- tempfile(fileext = ".json"); of <- tempfile(fileext = ".json")
    on.exit(unlink(c(pf, of)))
    drop_null <- function(p) p[!vapply(p, is.null, NA)]
    jsonlite::write_json(list(tiles2hex = drop_null(hex$params),
                              topic_model = drop_null(model$params)),
                         pf, auto_unbox = TRUE, null = "null", digits = NA)
    args <- c(script, "write", "--target", target, "--source", sdata, "--run", name,
              "--hex", hex$files$data, "--hex-json", hex$files$meta,
              "--results", model$files$results, "--model", model$files$model,
              "--params", pf, "--points-key", points_key, "--out", of)
    if (!is.null(coordinate_system)) args <- c(args, "--coordinate-system", coordinate_system)
    if (overwrite) args <- c(args, "--overwrite")
    run_tool(py, args, log, what = "punkst_to_sdata.py write")
    res <- jsonlite::read_json(of)
    invisible(structure(target, run = name, shapes = res$shapes, table = res$table))
}

#' List the punkst runs stored in a SpatialData store
#'
#' @param sdata Path to a store written by [sdata_writeback()].
#' @param python Interpreter override; see [punkst_setup()].
#' @param log Log file.
#' @return A data frame with one row per run: `run`, `table`, `n_hexagons`,
#'   `n_genes`, `n_topics`, `hex_size` and a list column `params` holding the
#'   recorded `tiles2hex` and `topic_model` parameters.
#' @export
sdata_runs <- function(sdata, python = NULL, log = tempfile("runs", fileext = ".log")) {
    if (!dir.exists(sdata)) stop("SpatialData store not found: ", sdata, call. = FALSE)
    py <- resolve_python(python)
    if (is.na(py) || !file.exists(py))
        stop("No Python interpreter found; see check_punkst_setup().", call. = FALSE)
    script <- system.file("python", "punkst_to_sdata.py", package = "punkstR")
    of <- tempfile(fileext = ".json"); on.exit(unlink(of))
    run_tool(py, c(script, "list", "--sdata", sdata, "--out", of), log,
             what = "punkst_to_sdata.py list")
    r <- jsonlite::read_json(of)
    if (!length(r)) return(data.frame(run = character(), table = character(),
        n_hexagons = integer(), n_genes = integer(), n_topics = integer(),
        hex_size = numeric(), params = I(list())))
    d <- data.frame(
        run = vapply(r, `[[`, "", "run"), table = vapply(r, `[[`, "", "table"),
        n_hexagons = vapply(r, `[[`, 0L, "n_hexagons"),
        n_genes = vapply(r, `[[`, 0L, "n_genes"),
        n_topics = vapply(r, `[[`, 0L, "n_topics"),
        hex_size = vapply(r, `[[`, 0, "hex_size"))
    d$params <- I(lapply(r, `[[`, "params"))
    d
}

#' Compare two punkst runs
#'
#' Topics have no fixed identity between fits, so each topic of `a` is paired
#' with its most similar topic of `b` (cosine similarity of the gene loadings,
#' over genes present in both; greedy one-to-one matching, best pairs first).
#' When both runs use the same hexagon grid the per-hexagon top-topic
#' assignments are also compared under that pairing.
#'
#' Works on files, so it needs no Python: give `punkstRun`/`punkstModel`
#' objects or paths to `*.model.tsv`.
#'
#' @param a,b Runs to compare: `punkstRun`, `punkstModel`, or model file paths.
#' @return A list with `pairs` (data frame: `topic_a`, `topic_b`, `cosine`),
#'   `similarity` (full topic x topic cosine matrix), `n_shared_genes`,
#'   and, when the grids match, `agreement` (fraction of shared hexagons whose
#'   top topics are paired) and `n_shared_hexagons`.
#' @export
punkst_compare_runs <- function(a, b) {
    ma <- if (inherits(a, "punkstRun")) a$model else a
    mb <- if (inherits(b, "punkstRun")) b$model else b
    A <- punkst_read_model(ma); B <- punkst_read_model(mb)
    g <- intersect(rownames(A), rownames(B))
    if (!length(g)) stop("The two models share no genes.", call. = FALSE)
    A <- A[g, , drop = FALSE]; B <- B[g, , drop = FALSE]
    A <- sweep(A, 2, sqrt(colSums(A^2)), "/"); B <- sweep(B, 2, sqrt(colSums(B^2)), "/")
    S <- crossprod(A, B)
    dimnames(S) <- list(colnames(A), colnames(B))
    pairs <- data.frame(topic_a = character(), topic_b = character(), cosine = numeric())
    W <- S
    for (i in seq_len(min(dim(S)))) {
        k <- which(W == max(W), arr.ind = TRUE)[1L, ]
        pairs[i, ] <- list(rownames(S)[k[1]], colnames(S)[k[2]], S[k[1], k[2]])
        W[k[1], ] <- -Inf; W[, k[2]] <- -Inf
    }
    out <- list(pairs = pairs, similarity = S, n_shared_genes = length(g))
    ra <- try(punkst_read_topics(ma), silent = TRUE)
    rb <- try(punkst_read_topics(mb), silent = TRUE)
    if (!inherits(ra, "try-error") && !inherits(rb, "try-error")) {
        m <- match_xy(ra$x, ra$y, rb$x, rb$y)
        ok <- !is.na(m)
        if (any(ok)) {
            top <- function(d) colnames(d)[-(1:3)][max.col(as.matrix(d[, -(1:3)]), "first")]
            ta <- top(ra)[ok]; tb <- top(rb)[m[ok]]
            paired <- pairs$topic_b[match(ta, pairs$topic_a)]
            out$agreement <- mean(paired == tb, na.rm = TRUE)
            out$n_shared_hexagons <- sum(ok)
        }
    }
    out
}
