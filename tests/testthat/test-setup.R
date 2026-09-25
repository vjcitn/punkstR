test_that("check_punkst_setup reports a missing binary with the doc pointer", {
    res <- check_punkst_setup(bin = tempfile("nope"), python = tempfile("nopy"), quiet = TRUE)
    expect_true(S7::S7_inherits(res, punkstConfig))
    expect_false(res@bin_ok)
    expect_false(res@python_ok)
    expect_true(any(grepl("install.md", res@notes)))
})

test_that("punkst_setup stores options and resolution prefers explicit args", {
    old <- options(punkstR.bin = NULL, punkstR.python = NULL)
    on.exit(options(old))
    punkst_setup(bin = "/some/where/punkst")
    expect_equal(punkstR:::resolve_bin(), "/some/where/punkst")
    expect_equal(punkstR:::resolve_bin("/other"), "/other")
})

test_that("run_tool raises with the log tail on failure", {
    log <- tempfile(fileext = ".log")
    expect_error(punkstR:::run_tool("/bin/sh", c("-c", "echo boom >&2; exit 3"), log),
                 "exit status 3.*boom")
    expect_silent(punkstR:::run_tool("/bin/sh", c("-c", "exit 0"), log))
})
