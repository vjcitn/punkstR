test_that("stage wrappers fail clearly on bad inputs", {
    expect_error(punkst_pts2tiles(tempfile(), tempdir(), bin = "/bin/sh"),
                 "Input not found")
    expect_error(punkst_tiles2hex(list()), "inherits")
})

test_that("run_stage skips when up to date and reruns when params change", {
    wd <- tempfile(); dir.create(wd)
    inp <- file.path(wd, "in.txt"); writeLines("a", inp)
    out <- file.path(wd, "out.txt")
    n <- 0
    go <- function(p, ow = FALSE)
        punkstR:::run_stage(wd, "s", list(p = p), inp, out, overwrite = ow,
                            run = function() { n <<- n + 1; writeLines("x", out) })
    suppressMessages(go(1)); expect_equal(n, 1)
    suppressMessages(go(1)); expect_equal(n, 1)          # skipped
    suppressMessages(go(2)); expect_equal(n, 2)          # params changed
    suppressMessages(go(2, ow = TRUE)); expect_equal(n, 3)
    Sys.sleep(1.1); writeLines("changed", inp)
    suppressMessages(go(2)); expect_equal(n, 4)          # input changed
})

test_that("full pipeline separates the two structured regions", {
    chk <- check_punkst_setup(quiet = TRUE)
    skip_if_not(chk$bin_ok && chk$python_ok, "punkst binary or python/spatialdata missing")
    fixture <- system.file("python", "make_synthetic_sdata.py", package = "punkstR")
    zarr <- tempfile(fileext = ".zarr")
    st <- system2(chk$python, c("-c", shQuote(sprintf(
        "import sys; sys.path.insert(0, %s); import make_synthetic_sdata as m; m.build_structured(%s)",
        shQuote(dirname(fixture), type = "cmd"), shQuote(zarr, type = "cmd")))),
        stdout = FALSE, stderr = FALSE)
    skip_if(!identical(as.integer(st), 0L), "could not build structured store")

    wd <- tempfile()
    run <- suppressMessages(run_punkst_pipeline(
        zarr, wd, tile_size = 100, hex_grid_dist = 12, min_count = 5,
        n_topics = 2, n_epochs = 5, min_count_train = 5, threads = 2,
        export = list(coordinate_system = NULL)))
    expect_s3_class(run, "punkstRun")
    expect_true(all(file.exists(unlist(run$model$files))))

    m <- read.delim(run$model$files$model, row.names = 1, check.names = FALSE)
    expect_equal(ncol(m), 2L)
    frac_a <- vapply(m, function(v) sum(v[startsWith(rownames(m), "A")]) / sum(v), 0)
    expect_gt(max(frac_a), 0.7)
    expect_lt(min(frac_a), 0.3)

    # second call reuses everything
    expect_message(run_punkst_pipeline(
        zarr, wd, tile_size = 100, hex_grid_dist = 12, min_count = 5,
        n_topics = 2, n_epochs = 5, min_count_train = 5, threads = 2,
        export = list(coordinate_system = NULL)), "up to date")
})
