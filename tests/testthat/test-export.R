python_with_sdata <- function() {
    chk <- check_punkst_setup(quiet = TRUE)
    if (!chk$python_ok) NULL else chk$python
}

test_that("sdata_export rejects a missing store", {
    expect_error(sdata_export(tempfile(), tempfile()), "not found")
})

test_that("sdata_export writes a punkst TSV from a synthetic store", {
    py <- python_with_sdata()
    skip_if(is.null(py), "python with spatialdata not available")
    fixture <- system.file("python", "make_synthetic_sdata.py", package = "punkstR")
    zarr <- tempfile(fileext = ".zarr")
    st <- system2(py, c(fixture, zarr), stdout = FALSE, stderr = FALSE)
    skip_if(!identical(as.integer(st), 0L), "could not build synthetic store")

    out <- tempfile(fileext = ".tsv")
    sdata_export(zarr, out, coordinate_system = "pixels", min_qv = 20)
    lines <- readLines(out)
    expect_match(lines[1], "^#x\ty\tfeature")
    df <- read.delim(out, comment.char = "#", header = FALSE)
    expect_equal(ncol(df), 3L)
    expect_gt(nrow(df), 0L)
    expect_lt(nrow(df), 200L)   # qv filter dropped some of the 200 rows
    # idempotent: second call skips
    expect_message(sdata_export(zarr, out, coordinate_system = "pixels"), "skipping")
})
