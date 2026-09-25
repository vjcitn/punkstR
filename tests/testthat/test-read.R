test_that("readers parse punkst output files", {
    d <- tempfile(); dir.create(d)
    writeLines(c("Feature\t0\t1", "A\t1.5\t2", "B\t3\t4"), file.path(d, "m.model.tsv"))
    m <- punkst_read_model(file.path(d, "m.model.tsv"))
    expect_equal(dim(m), c(2L, 2L))
    expect_equal(rownames(m), c("A", "B"))
    expect_equal(unname(m["B", "1"]), 4)

    writeLines(c("#random_key\tx\ty\t0\t1", "00ab\t1.0\t2.0\t0.25\t0.75",
                 "00ab\t3.0\t4.0\t0.5\t0.5"), file.path(d, "m.results.tsv"))
    r <- punkst_read_topics(file.path(d, "m.results.tsv"))
    expect_equal(names(r), c("key", "x", "y", "0", "1"))
    expect_equal(r$key, c("00ab", "00ab"))
    writeLines(c("#random_key\tx\ty\t0\t1\t2\t3\t4\t5", "k\t1\t2\t1\t2\t3\t4\t5\t6"),
               file.path(d, "w.results.tsv"))
    w <- punkst_read_topics(file.path(d, "w.results.tsv"))
    expect_true(all(vapply(w[-1L], is.numeric, NA)))

    writeLines(c("k1\t1\t2\t2\t5\t0 3\t2 2", "k2\t3\t4\t1\t4\t1 4"), file.path(d, "h.txt"))
    writeLines('{"dictionary": {"G0": 0, "G1": 1, "G2": 2}}', file.path(d, "h.json"))
    h <- punkst_read_hex(file.path(d, "h.txt"))
    expect_equal(dim(h$counts), c(2L, 3L))
    expect_equal(colnames(h$counts), c("G0", "G1", "G2"))
    expect_equal(unname(h$counts[1, "G2"]), 2)
    expect_equal(unname(h$counts[2, "G1"]), 4)
    expect_equal(rowSums(as.matrix(h$counts)), h$units$total)

    writeLines(c("G0\t10", "G1\t5"), file.path(d, "f.tsv"))
    f <- punkst_read_features(file.path(d, "f.tsv"))
    expect_equal(f$feature, c("G0", "G1"))
    expect_error(punkst_read_model(structure(list(files = list()), class = "punkstModel")),
                 "no 'model' file")
})

test_that("match_xy matches on centres and rejects duplicate references", {
    rx <- c(1, 2, 3); ry <- c(5, 6, 7)
    expect_equal(match_xy(c(3, 1, 9), c(7, 5, 9), rx, ry), c(3L, 1L, NA))
    expect_equal(match_xy(1.00004, 5, rx, ry), 1L)
    expect_error(match_xy(1, 1, c(1, 1), c(2, 2)), "not unique")
})

test_that("sdata_info summarises a synthetic store", {
    py <- Sys.getenv("PUNKST_PYTHON")
    skip_if(!nzchar(py) || !file.exists(py), "PUNKST_PYTHON not set")
    skip_if(system2(py, c("-c", shQuote("import spatialdata")), stdout = FALSE,
                    stderr = FALSE) != 0, "spatialdata not importable")
    d <- tempfile(); dir.create(d)
    zarr <- file.path(d, "s.zarr")
    gen <- system.file("python", "make_synthetic_sdata.py", package = "punkstR")
    expect_equal(system2(py, c(shQuote(gen), shQuote(zarr)), stdout = FALSE, stderr = FALSE), 0L)
    info <- sdata_info(zarr, python = py)
    expect_equal(info$points$transcripts$rows, 200L)
    expect_true("pixels" %in% names(info$points$transcripts$transformations))
    expect_equal(info$points$transcripts$transformations$microns$scale[[1]], 2)
})
