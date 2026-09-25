# punkstR

Drive the [punkst](https://github.com/Yichen-Si/punkst) spatial transcriptomics
pipeline from R. punkstR checks that the required executables and files exist,
then runs them with `system2()`. It does **not** use reticulate or import any
Python module into R.

Status: early development. Implemented so far: setup checks and the SpatialData
export. Planned: wrappers for `pts2tiles`, `tiles2hex` and `topic-model`, readers
for the results, and an optional `SpatialExperiment` adapter.

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
