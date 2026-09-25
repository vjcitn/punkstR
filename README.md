# punkstR

Drive the [punkst](https://github.com/Yichen-Si/punkst) spatial transcriptomics
pipeline from R. punkstR checks that the required executables and files exist,
then runs them with `system2()`. It does **not** use reticulate or import any
Python module into R.

Status: early development. Implemented so far: setup checks, the SpatialData
export, and wrappers for `pts2tiles`, `tiles2hex` and `topic-model` with a
one-call pipeline. Planned: readers for the results and an optional
`SpatialExperiment` adapter.

## What you need

1. **The `punkst` binary.** See [Building punkst](#building-punkst) below.
2. **A Python interpreter with `spatialdata`**, only for exporting SpatialData
   (zarr) stores. Stores written by recent spatialdata are zarr v3 and need
   `spatialdata >= 0.7`. A dedicated virtual environment is a good choice.

Point punkstR at them with `punkst_setup(bin = , python = )`, or with the
`PUNKST` and `PUNKST_PYTHON` environment variables, then run:

```r
library(punkstR)
check_punkst_setup()
```

which reports what it found, including the spatialdata and zarr versions, and
what to fix.

## Export a SpatialData store

```r
sdata_export("data.zarr", "transcripts.tsv",
             points_key = "transcripts",
             coordinate_system = "intrinsic",  # microns for Xenium
             min_qv = 20)
```

The output is a tab-separated file with a `#` header, ready for
`punkst pts2tiles`. For Xenium stores, `spatialdata-io` registers the transcripts
in `global` (image pixels) through a scale transform while the stored coordinates
are microns, which is what punkst expects, hence `"intrinsic"`.

## Run the pipeline

```r
run <- run_punkst_pipeline(
    "data.zarr", workdir = "xenium_run",
    export = list(coordinate_system = "intrinsic", min_qv = 20),
    tiles2hex = list(hex_grid_dist = 12),
    topic_model = list(n_topics = 12, n_epochs = 2, sort_topics = TRUE,
                       exclude_feature_regex = xenium_control_regex()))
run$model$files$results   # per-hexagon topic probabilities
```

Each stage function exposes the options of the matching punkst command with punkst's own defaults (see `?punkst_pts2tiles`, `?punkst_tiles2hex`, `?punkst_topic_model`), and `run_punkst_pipeline()` takes each stage's options as a list.

You can also call the stages one at a time (`sdata_export()`, `punkst_pts2tiles()`,
`punkst_tiles2hex()`, `punkst_topic_model()`), each taking the previous stage's
result. Each stage writes a log in `workdir`, and a manifest records its
parameters and inputs; re-running skips stages whose outputs exist and whose
parameters and input files are unchanged (`overwrite = TRUE` forces a re-run).

## Write results back and compare tuning runs

```r
run <- run_punkst_pipeline("data.zarr", "work",
                           topic_model = list(n_topics = 12))
sdata_writeback(run)                      # -> data_punkst.zarr (sidecar store)
sdata_writeback(run, in_place = TRUE)     # -> into data.zarr itself

# explore other settings; each run gets its own elements in the store
run8 <- run_punkst_pipeline("data.zarr", "work",
                            topic_model = list(n_topics = 8))
sdata_writeback(run8)

sdata_runs("data_punkst.zarr")            # runs with recorded parameters
punkst_compare_runs(run, run8)            # topic pairing + hexagon agreement
```

Each run adds a `shapes` element `punkst_<run>_hexagons` (with the source
points' transformations, so hexagons overlay transcripts and images) and a
`table` `punkst_<run>` (counts, `obsm["topics"]`, `varm["loadings"]`, run
parameters in `uns`). Runs never overwrite each other unless `overwrite = TRUE`.
Vary hexagon size or other settings by using a different `work` directory or
a `name`.

## Building punkst

The canonical recipe is in the punkst documentation:
<https://github.com/vjcitn/punkst/blob/spatialdata-bridge/docs/install.md>
(section "Minimal Build Without a Package Manager"). In short, for a build that
needs no TBB, libpng or libcurl (only Git, CMake >= 3.15, a C++17 compiler and
the system zlib, BZip2 and LibLZMA):

```bash
git clone https://github.com/your-org/punkst.git
cd punkst
git submodule update --init ext/eigen ext/faiss ext/clipper2

mkdir -p build && cd build
cmake .. \
  -DFETCH_TBB=ON \
  -DENABLE_IMAGE_OUTPUT=OFF \
  -DENABLE_REMOTE_IO=OFF \
  -DENABLE_NATIVE_ARCH=OFF
cmake --build . --parallel
../bin/punkst --help
```

Then `punkst_setup(bin = "/path/to/punkst/bin/punkst")`. If you do not need this,
ignore it: punkstR never builds or installs anything.

## Tests

```r
devtools::test()
```

Tests that need Python with spatialdata skip themselves when it is not
available.

## Vignette

`vignette("xenium-breast", package = "punkstR")` walks through a Xenium breast
cancer section using only punkstR functions and base R. It runs when
`PUNKSTR_DEMO_ZARR` points at the demonstration SpatialData store and the
`punkst` binary and Python are available (`PUNKST`, `PUNKST_PYTHON`);
otherwise its code is shown but not evaluated. Set `PUNKSTR_DEMO_WORKDIR` to
keep intermediate files (about 2 GB) between renders. Building vignettes needs
the Quarto command line tool.

Result readers: `punkst_read_model()`, `punkst_read_topics()`,
`punkst_read_hex()` (sparse hexagon x gene counts), `punkst_read_features()`
and `match_xy()`; `sdata_info()` summarises a store.
