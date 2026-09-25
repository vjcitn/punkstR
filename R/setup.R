# Locating and checking the external tools punkstR relies on.

.install_doc <- "https://github.com/vjcitn/punkst/blob/spatialdata-bridge/docs/install.md"

#' First usable value
#'
#' @param ... Candidate values, in priority order.
#' @return The first length-one, non-missing, non-empty string, or `NULL`.
#' @noRd
.first_nonempty <- function(...) {
    for (x in list(...)) {
        if (!is.null(x) && length(x) == 1L && !is.na(x) && nzchar(x)) return(x)
    }
    NULL
}

#' Configure the punkst executable and Python interpreter
#'
#' Records where to find the `punkst` binary and the Python interpreter used
#' for the SpatialData export script. Values are stored in
#' `options(punkstR.bin, punkstR.python)`. Nothing is run or validated here;
#' use [check_punkst_setup()].
#'
#' Resolution order when an argument is `NULL`: the option, then the
#' environment variable (`PUNKST`, `PUNKST_PYTHON`), then the `PATH`.
#'
#' @param bin Path to the `punkst` binary.
#' @param python Path to a Python interpreter that has `spatialdata` installed.
#' @return The resolved settings, invisibly, as a list.
#' @export
punkst_setup <- function(bin = NULL, python = NULL) {
    if (!is.null(bin)) options(punkstR.bin = path.expand(bin))
    if (!is.null(python)) options(punkstR.python = path.expand(python))
    invisible(list(bin = resolve_bin(), python = resolve_python()))
}

#' Locate the punkst binary
#'
#' Order: `bin`, `options(punkstR.bin)`, env var `PUNKST`, then the `PATH`.
#'
#' @param bin Explicit path, or `NULL`.
#' @return A path, or `NA_character_` if none was found.
#' @noRd
resolve_bin <- function(bin = NULL) {
    b <- .first_nonempty(
        bin, getOption("punkstR.bin"), Sys.getenv("PUNKST", ""),
        unname(Sys.which("punkst")))
    if (is.null(b)) NA_character_ else path.expand(b)
}

#' Locate the Python interpreter
#'
#' Order: `python`, `options(punkstR.python)`, env var `PUNKST_PYTHON`, then
#' `python3` on the `PATH`.
#'
#' @param python Explicit path, or `NULL`.
#' @return A path, or `NA_character_` if none was found.
#' @noRd
resolve_python <- function(python = NULL) {
    p <- .first_nonempty(
        python, getOption("punkstR.python"), Sys.getenv("PUNKST_PYTHON", ""),
        unname(Sys.which("python3")))
    if (is.null(p)) NA_character_ else path.expand(p)
}

#' Run an executable through `system2()`
#'
#' Sends stdout and stderr to `log`. Arguments are passed as a vector and
#' quoted here, so paths with spaces need no quoting by the caller. Stops with
#' the tail of the log on a non-zero exit status.
#'
#' @param command Executable to run.
#' @param args Character vector of arguments.
#' @param log Log file path; its directory is created.
#' @param what Name used in error messages.
#' @return `log`, invisibly.
#' @noRd
run_tool <- function(command, args, log, what = basename(command)) {
    dir.create(dirname(log), showWarnings = FALSE, recursive = TRUE)
    status <- suppressWarnings(
        system2(command, args = shQuote(as.character(args)),
                stdout = log, stderr = log))
    if (!identical(as.integer(status), 0L)) {
        lines <- if (file.exists(log)) readLines(log, warn = FALSE) else character()
        stop(sprintf("%s failed with exit status %s. Last log lines (%s):\n%s",
                     what, status, log,
                     paste(utils::tail(lines, 15), collapse = "\n")),
             call. = FALSE)
    }
    invisible(log)
}

#' Check that the required tools are available
#'
#' Looks for the `punkst` binary and a Python interpreter with `spatialdata`
#' and reports what was found. It runs each tool once (`punkst --help` and a
#' short `python -c` import) but never installs or builds anything. If the
#' binary is missing, the message points to the build recipe.
#'
#' @param bin,python Optional overrides; see [punkst_setup()].
#' @param quiet If `FALSE`, print a summary.
#' @return An object of class `punkstCheck`: a list with `bin`, `python`,
#'   `bin_ok`, `python_ok`, `spatialdata_version`, `zarr_version`, `notes`.
#' @export
check_punkst_setup <- function(bin = NULL, python = NULL, quiet = FALSE) {
    bin <- resolve_bin(bin)
    python <- resolve_python(python)
    notes <- character()

    bin_ok <- FALSE
    if (is.na(bin) || !file.exists(bin)) {
        notes <- c(notes, sprintf(
            "punkst binary not found (%s). Set it with punkst_setup(bin=), or set the PUNKST environment variable. To build it, see %s or the punkstR README.",
            if (is.na(bin)) "no path given" else bin, .install_doc))
    } else if (file.access(bin, mode = 1L) != 0L) {
        notes <- c(notes, sprintf("%s exists but is not executable.", bin))
    } else {
        out <- suppressWarnings(tryCatch(
            system2(bin, "--help", stdout = TRUE, stderr = TRUE),
            error = function(e) character()))
        bin_ok <- any(grepl("Available Commands", out, fixed = TRUE))
        if (!bin_ok)
            notes <- c(notes, sprintf(
                "%s did not print the expected help text; is it a punkst binary?", bin))
    }

    python_ok <- FALSE
    sd_version <- zarr_version <- NA_character_
    if (is.na(python) || !nzchar(python) || !file.exists(python)) {
        notes <- c(notes, "No Python interpreter found. Set one with punkst_setup(python=) or PUNKST_PYTHON.")
    } else {
        out <- suppressWarnings(tryCatch(
            system2(python, c("-c", shQuote(
                "import spatialdata, zarr; print(spatialdata.__version__); print(zarr.__version__)")),
                stdout = TRUE, stderr = TRUE),
            error = function(e) character()))
        status <- attr(out, "status")
        if (is.null(status) && length(out) >= 2L) {
            python_ok <- TRUE
            sd_version <- out[length(out) - 1L]
            zarr_version <- out[length(out)]
            if (numeric_version(zarr_version, strict = FALSE) < "3")
                notes <- c(notes, sprintf(
                    "zarr %s (spatialdata %s) cannot read zarr v3 stores, which recent spatialdata writes; use spatialdata >= 0.7 for those.",
                    zarr_version, sd_version))
        } else {
            notes <- c(notes, sprintf(
                "%s could not import spatialdata and zarr. Output: %s",
                python, paste(utils::tail(out, 3), collapse = " | ")))
        }
    }

    res <- structure(list(bin = bin, python = python, bin_ok = bin_ok,
                          python_ok = python_ok,
                          spatialdata_version = sd_version,
                          zarr_version = zarr_version, notes = notes),
                     class = "punkstCheck")
    if (!quiet) print(res)
    invisible(res)
}

#' Print a setup check
#'
#' @param x A `punkstCheck` object from [check_punkst_setup()].
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
#' @noRd
print.punkstCheck <- function(x, ...) {
    mark <- function(ok) if (ok) "OK     " else "MISSING"
    cat("punkst binary :", mark(x$bin_ok), format(x$bin), "\n")
    cat("python/sdata  :", mark(x$python_ok), format(x$python),
        if (x$python_ok) sprintf("(spatialdata %s, zarr %s)",
                                 x$spatialdata_version, x$zarr_version), "\n")
    for (n in x$notes) cat("* ", n, "\n", sep = "")
    invisible(x)
}
