# punkstR 0.99.2

## Bug fixes

* `punkst_topic_model()` no longer requires a `.state.tsv` output: the
  released `punkst` binary (v0.1.2) never writes it (that output was added
  to `fit_lda.cpp` only after the v0.1.2 tag), so requiring it made the
  vignette and CI tests fail on every supported install. `state` is now
  included in the returned `files` only when the `punkst` build in use
  actually produced it, and the `punkstModel` validator no longer requires
  it.
* Fixed CI so the vignette and all `@examples` genuinely execute (rather
  than silently skipping) during `R CMD check`, and the `testthat` suite
  runs with zero skips.

# punkstR 0.99.0

## New features

* Initial release: a thin, `system2()`-based R driver for the `punkst`
  spatial transcriptomics pipeline (no `reticulate`, no Python imported
  into R).
* `check_punkst_setup()` locates the `punkst` binary and a Python
  interpreter with `spatialdata` installed.
* `sdata_export()` exports SpatialData (zarr) points elements to the
  transcript format `punkst` expects.
* Formal S7 classes model the pipeline stages: `punkstConfig`,
  `punkstStage` (and its `punkstTiles`/`punkstHex`/`punkstModel`
  subclasses), and `punkstRun`.
* Stage wrappers (`punkst_tiles()`, `punkst_hex()`, `punkst_topic_model()`)
  and a one-call `run_punkst_pipeline()`, with manifest-based skipping of
  stages that are already up to date.
* Result readers: `punkst_read_model()`, `punkst_read_topics()`,
  `punkst_read_hex()`, `punkst_read_features()`, `match_xy()`.
* `sdata_writeback()` writes a run's hexagon shapes and topic results back
  into a SpatialData store (new sidecar store by default, or in place);
  `sdata_runs()` lists stored runs; `punkst_compare_runs()` compares two
  runs' topic loadings (and, when grids match, per-hexagon topic
  agreement) without needing Python.
* `sdata_demo()` builds a small synthetic SpatialData store for the
  package's vignette and examples.

## Bioconductor submission readiness

* Version set to the `0.99.0` new-submission convention; added
  `biocViews`, `URL`, `BugReports`, `SystemRequirements` to `DESCRIPTION`.
* Added `@examples` to all exported functions and classes, guarded with
  `tryCatch()` where they need the `punkst` binary or a spatialdata-enabled
  Python so they degrade gracefully instead of erroring when those aren't
  present.
* Fixed a latent bug in `punkst_compare_runs()` where the per-hexagon
  agreement computation ran outside the `try()` meant to make it optional.
* Added a GitHub Actions workflow (`R-CMD-check.yaml`) running `R CMD
  check` and `BiocCheck` on every push/PR, installing a real Python
  environment (`numpy`/`pandas`/`scipy`/`spatialdata`) and a prebuilt
  `punkst` binary so the vignette and examples actually run in CI rather
  than being skipped.
