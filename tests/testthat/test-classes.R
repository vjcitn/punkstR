test_that("stage classes validate their files", {
    expect_error(punkstHex(workdir = "w", files = list(data = "a"), params = list()), "meta")
    expect_error(punkstTiles(workdir = "w", files = list("a"), params = list()), "named")
    expect_error(punkstModel(workdir = c("a", "b"), files = list(), params = list()), "single")
    expect_error(punkstStage(), "abstract")
    h <- punkstHex(workdir = "w", files = list(data = "a", meta = "b"), params = list())
    expect_true(S7::S7_inherits(h, punkstStage))
    expect_output(print(h), "<punkstHex> in w")
})

test_that("punkstConfig validates, prints, and is accepted as bin/python", {
    cfg <- punkstConfig(bin = "/x/punkst", python = "/x/py", bin_ok = FALSE,
                        python_ok = FALSE, spatialdata_version = NA_character_,
                        zarr_version = NA_character_, notes = "n")
    expect_output(print(cfg), "MISSING")
    expect_error(punkstConfig(bin = c("a", "b"), python = "p", bin_ok = TRUE,
                              python_ok = TRUE, spatialdata_version = "1",
                              zarr_version = "3"), "length 1")
    expect_equal(punkstR:::resolve_bin(cfg), "/x/punkst")
    expect_equal(punkstR:::resolve_python(cfg), "/x/py")
})
