test_that("write-back stores several runs side by side and they can be compared", {
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
    go <- function(k) suppressMessages(run_punkst_pipeline(
        zarr, wd, threads = 2, export = list(coordinate_system = NULL),
        pts2tiles = list(tile_size = 100), tiles2hex = list(min_count = 5),
        topic_model = list(n_topics = k, n_epochs = 5, min_count_train = 5)))
    r2 <- go(2); r3 <- go(3)
    expect_equal(r2$source$sdata, zarr)

    side <- tempfile(fileext = ".zarr")
    o1 <- sdata_writeback(r2, out = side)
    sdata_writeback(r3, out = side)
    runs <- sdata_runs(side)
    expect_setequal(runs$run, c("hex_12_k2", "hex_12_k3"))
    expect_equal(sort(runs$n_topics), 2:3)
    expect_equal(runs$params[[which(runs$n_topics == 3)]]$topic_model$n_topics, 3)

    # existing run is refused unless overwrite
    expect_error(sdata_writeback(r2, out = side), "already exists")
    expect_no_error(sdata_writeback(r2, out = side, overwrite = TRUE))
    expect_equal(nrow(sdata_runs(side)), 2L)

    # the original store is untouched by the sidecar write
    expect_equal(nrow(sdata_runs(zarr)), 0L)
    # custom name, and in-place write into the initiating store
    sdata_writeback(r3, in_place = TRUE, name = "my k3")
    expect_equal(sdata_runs(zarr)$run, "my_k3")
    info <- sdata_info(zarr)
    expect_true("transcripts" %in% names(info$points))
    expect_true("punkst_my_k3_hexagons" %in% unlist(info$shapes))

    cmp <- punkst_compare_runs(r2, r3)
    expect_equal(nrow(cmp$pairs), 2L)
    expect_gt(cmp$n_shared_hexagons, 0)
    expect_gte(cmp$agreement, 0); expect_lte(cmp$agreement, 1)
    self <- punkst_compare_runs(r2, r2)
    expect_equal(self$pairs$cosine, c(1, 1), tolerance = 1e-6)
    expect_equal(self$agreement, 1)
})
