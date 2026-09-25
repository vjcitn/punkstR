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
    hex_grid_dist = 12, n_topics = 12,
    topic_model = list(n_epochs = 2, sort_topics = TRUE,
                       exclude_feature_regex = xenium_control_regex()))
run$model$files$results   # per-hexagon topic probabilities
```

`punkst_topic_model()` exposes the options of `punkst topic-model` for hexagon input, with punkst's own defaults (see `?punkst_topic_model`).

You can also call the stages one at a time (`sdata_export()`, `punkst_pts2tiles()`,
`punkst_tiles2hex()`, `punkst_topic_model()`), each taking the previous stage's
result. Each stage writes a log in `workdir`, and a manifest records its
parameters and inputs; re-running skips stages whose outputs exist and whose
parameters and input files are unchanged (`overwrite = TRUE` forces a re-run).

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
