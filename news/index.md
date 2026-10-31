# Changelog

## punkstR 0.99.2

### Bug fixes

- [`punkst_topic_model()`](https://vjcitn.github.io/punkstR/reference/punkst_topic_model.md)
  no longer requires a `.state.tsv` output: the released `punkst` binary
  (v0.1.2) never writes it (that output was added to `fit_lda.cpp` only
  after the v0.1.2 tag), so requiring it made the vignette and CI tests
  fail on every supported install. `state` is now included in the
  returned `files` only when the `punkst` build in use actually produced
  it, and the `punkstModel` validator no longer requires it.
- Fixed CI so the vignette and all `@examples` genuinely execute (rather
  than silently skipping) during `R CMD check`, and the `testthat` suite
  runs with zero skips.

## punkstR 0.99.0

### New features

- Initial release: a thin,
  [`system2()`](https://rdrr.io/r/base/system2.html)-based R driver for
  the `punkst` spatial transcriptomics pipeline (no `reticulate`, no
  Python imported into R).
- [`check_punkst_setup()`](https://vjcitn.github.io/punkstR/reference/check_punkst_setup.md)
  locates the `punkst` binary and a Python interpreter with
  `spatialdata` installed.
- [`sdata_export()`](https://vjcitn.github.io/punkstR/reference/sdata_export.md)
  exports SpatialData (zarr) points elements to the transcript format
  `punkst` expects.
- Formal S7 classes model the pipeline stages: `punkstConfig`,
  `punkstStage` (and its `punkstTiles`/`punkstHex`/`punkstModel`
  subclasses), and `punkstRun`.
- Stage wrappers (`punkst_tiles()`, `punkst_hex()`,
  [`punkst_topic_model()`](https://vjcitn.github.io/punkstR/reference/punkst_topic_model.md))
  and a one-call
  [`run_punkst_pipeline()`](https://vjcitn.github.io/punkstR/reference/run_punkst_pipeline.md),
  with manifest-based skipping of stages that are already up to date.
- Result readers:
  [`punkst_read_model()`](https://vjcitn.github.io/punkstR/reference/punkst_read_model.md),
  [`punkst_read_topics()`](https://vjcitn.github.io/punkstR/reference/punkst_read_topics.md),
  [`punkst_read_hex()`](https://vjcitn.github.io/punkstR/reference/punkst_read_hex.md),
  [`punkst_read_features()`](https://vjcitn.github.io/punkstR/reference/punkst_read_features.md),
  [`match_xy()`](https://vjcitn.github.io/punkstR/reference/match_xy.md).
- [`sdata_writeback()`](https://vjcitn.github.io/punkstR/reference/sdata_writeback.md)
  writes a run’s hexagon shapes and topic results back into a
  SpatialData store (new sidecar store by default, or in place);
  [`sdata_runs()`](https://vjcitn.github.io/punkstR/reference/sdata_runs.md)
  lists stored runs;
  [`punkst_compare_runs()`](https://vjcitn.github.io/punkstR/reference/punkst_compare_runs.md)
  compares two runs’ topic loadings (and, when grids match, per-hexagon
  topic agreement) without needing Python.
- [`sdata_demo()`](https://vjcitn.github.io/punkstR/reference/sdata_demo.md)
  builds a small synthetic SpatialData store for the package’s vignette
  and examples.

### Bioconductor submission readiness

- Version set to the `0.99.0` new-submission convention; added
  `biocViews`, `URL`, `BugReports`, `SystemRequirements` to
  `DESCRIPTION`.
- Added `@examples` to all exported functions and classes, guarded with
  [`tryCatch()`](https://rdrr.io/r/base/conditions.html) where they need
  the `punkst` binary or a spatialdata-enabled Python so they degrade
  gracefully instead of erroring when those aren’t present.
- Fixed a latent bug in
  [`punkst_compare_runs()`](https://vjcitn.github.io/punkstR/reference/punkst_compare_runs.md)
  where the per-hexagon agreement computation ran outside the
  [`try()`](https://rdrr.io/r/base/try.html) meant to make it optional.
- Added a GitHub Actions workflow (`R-CMD-check.yaml`) running
  `R CMD check` and `BiocCheck` on every push/PR, installing a real
  Python environment (`numpy`/`pandas`/`scipy`/`spatialdata`) and a
  prebuilt `punkst` binary so the vignette and examples actually run in
  CI rather than being skipped.
