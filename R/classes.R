#' @import S7
NULL

# Class design
#
#   punkstConfig                 resolved tools + what was verified about them
#   punkstStage (abstract)       one executed pipeline stage: workdir, files, params
#     |- punkstTiles             pts2tiles output
#     |- punkstHex               tiles2hex output
#     `- punkstModel             topic-model output
#   punkstRun                    the four pieces of one pipeline run + its source
#
# Instances are immutable in spirit: they are created by the stage functions
# and hold no behaviour beyond validation and printing. Properties are read
# with `@` (e.g. `hex@files$data`).

.is_string <- function(x) length(x) == 1L
.need_files <- function(files, needed)
    if (!all(needed %in% names(files)))
        paste0("@files must include: ", paste(setdiff(needed, names(files)), collapse = ", "))

#' Resolved punkst configuration
#'
#' Holds the punkst executable and Python interpreter that were resolved
#' (argument, then option, then environment variable, then `PATH`; see
#' [punkst_setup()]) together with what checking them found. It is created by
#' [check_punkst_setup()]; you would rarely construct one yourself. A
#' `punkstConfig` can be passed wherever a `bin` or `python` argument is
#' accepted, in which case the corresponding path is used.
#'
#' @param bin Path to the punkst executable, or `NA_character_` if none found.
#' @param python Path to the Python interpreter, or `NA_character_`.
#' @param bin_ok `TRUE` if `bin` exists, is executable and prints punkst's
#'   help text.
#' @param python_ok `TRUE` if `python` can import `spatialdata` and `zarr`.
#' @param spatialdata_version,zarr_version Versions reported by the
#'   interpreter, `NA_character_` if unavailable.
#' @param notes Character vector of actionable messages about what is missing
#'   (never installs anything; points to the build recipe).
#' @return A `punkstConfig` object; use `@` to read its properties.
#' @export
punkstConfig <- new_class("punkstConfig", package = NULL,
    properties = list(
        bin = class_character, python = class_character,
        bin_ok = class_logical, python_ok = class_logical,
        spatialdata_version = class_character, zarr_version = class_character,
        notes = class_character),
    validator = function(self) {
        if (!all(vapply(list(self@bin, self@python, self@bin_ok, self@python_ok,
                             self@spatialdata_version, self@zarr_version),
                        .is_string, NA)))
            "bin, python, bin_ok, python_ok and the versions must each have length 1"
    })

#' Pipeline stage (abstract parent class)
#'
#' Common structure of the objects returned by [punkst_pts2tiles()],
#' [punkst_tiles2hex()] and [punkst_topic_model()]. `punkstStage` itself is
#' abstract; use the subclasses `punkstTiles`, `punkstHex` and `punkstModel`.
#'
#' @param workdir Directory holding the stage's outputs.
#' @param files Named list of output file paths. Required names: `punkstTiles`
#'   `tsv`, `index`, `features`; `punkstHex` `data`, `meta`; `punkstModel`
#'   `model`, `state` (plus `results` and `pseudobulk` when fitted with
#'   `transform = TRUE`).
#' @param params Named list of the parameters that produced the outputs. These
#'   also drive the skip-if-up-to-date manifest and are recorded by
#'   [sdata_writeback()].
#' @return An object of the respective subclass.
#' @name punkstStage
#' @export
punkstStage <- new_class("punkstStage", package = NULL, abstract = TRUE,
    properties = list(workdir = class_character, files = class_list,
                      params = class_list),
    validator = function(self) {
        if (length(self@workdir) != 1L) return("@workdir must be a single path")
        if (length(self@files) && (is.null(names(self@files)) || anyNA(names(self@files))))
            return("@files must be a named list")
    })

#' @rdname punkstStage
#' @export
punkstTiles <- new_class("punkstTiles", parent = punkstStage, package = NULL,
    validator = function(self) .need_files(self@files, c("tsv", "index", "features")))

#' @rdname punkstStage
#' @export
punkstHex <- new_class("punkstHex", parent = punkstStage, package = NULL,
    validator = function(self) .need_files(self@files, c("data", "meta")))

#' @rdname punkstStage
#' @export
punkstModel <- new_class("punkstModel", parent = punkstStage, package = NULL,
    validator = function(self) .need_files(self@files, c("model", "state")))

#' One pipeline run
#'
#' The result of [run_punkst_pipeline()]: the exported transcripts file, the
#' three stage objects, and where the data came from (needed by
#' [sdata_writeback()] to align results with the source store).
#'
#' @param transcripts Path to the exported transcripts file.
#' @param tiles,hex,model The `punkstTiles`, `punkstHex` and `punkstModel`
#'   stage objects.
#' @param source List with `sdata` (store path), `points_key` and
#'   `coordinate_system` (as used for export; may be `NULL`).
#' @return A `punkstRun` object.
#' @export
punkstRun <- new_class("punkstRun", package = NULL,
    properties = list(transcripts = class_character, tiles = punkstTiles,
                      hex = punkstHex, model = punkstModel, source = class_list),
    constructor = function(transcripts, tiles, hex, model, source)
        new_object(S7_object(), transcripts = transcripts, tiles = tiles,
                   hex = hex, model = model, source = source),
    validator = function(self) {
        if (length(self@transcripts) != 1L) return("@transcripts must be a single path")
        if (!all(c("sdata", "points_key") %in% names(self@source)))
            return("@source must have 'sdata' and 'points_key'")
    })

# ---- printing (registered with S7::methods_register() in .onLoad)

method(print, punkstConfig) <- function(x, ...) {
    mark <- function(ok) if (ok) "OK     " else "MISSING"
    cat("punkst binary :", mark(x@bin_ok), format(x@bin), "\n")
    cat("python/sdata  :", mark(x@python_ok), format(x@python),
        if (x@python_ok) sprintf("(spatialdata %s, zarr %s)",
                                 x@spatialdata_version, x@zarr_version), "\n")
    for (n in x@notes) cat("* ", n, "\n", sep = "")
    invisible(x)
}

method(print, punkstStage) <- function(x, ...) {
    cat("<", class(x)[1], "> in ", x@workdir, "\n", sep = "")
    for (n in names(x@files)) cat(sprintf("  %-9s %s\n", n, x@files[[n]]))
    invisible(x)
}

method(print, punkstRun) <- function(x, ...) {
    cat("<punkstRun>\n")
    cat("  source     :", x@source$sdata, "\n")
    cat("  transcripts:", x@transcripts, "\n")
    for (s in c("tiles", "hex", "model")) print(prop(x, s))
    invisible(x)
}

.onLoad <- function(libname, pkgname) S7::methods_register()
