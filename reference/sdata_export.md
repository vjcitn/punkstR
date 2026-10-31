# Export a SpatialData points element to punkst transcript format

Runs the bundled `spatialdata_to_punkst.py` with
[`system2()`](https://rdrr.io/r/base/system2.html); no Python module is
loaded into R. The output is a tab-separated file with a `#`-prefixed
header and columns `x`, `y`, `feature`, ready for `punkst pts2tiles`.

## Usage

``` r
sdata_export(
  sdata,
  out,
  points_key = "transcripts",
  coordinate_system = "intrinsic",
  min_qv = NULL,
  qv_column = "qv",
  feature_column = NULL,
  overwrite = FALSE,
  python = NULL,
  log = paste0(out, ".export.log")
)
```

## Arguments

- sdata:

  Path to the SpatialData `.zarr` store.

- out:

  Output path (`.tsv` or `.tsv.gz`).

- points_key:

  Name of the points element.

- coordinate_system:

  Coordinate system to export in, or `"intrinsic"` for the stored
  coordinates. `NULL` lets the script infer it when only one is
  registered.

- min_qv:

  Drop rows with quality below this value (e.g. 20 for Xenium).

- qv_column:

  Name of the quality column.

- feature_column:

  Feature column; default is the element's feature key.

- overwrite:

  Re-export if `out` already exists.

- python:

  Interpreter override; see
  [`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md).

- log:

  Log file for the script's output.

## Value

The output path, invisibly.

## Details

For Xenium stores written by `spatialdata-io`, the stored coordinates
are microns while the registered `global` coordinate system is image
pixels, so the default `coordinate_system = "intrinsic"` exports microns
as punkst expects.

## Examples

``` r
# Requires a Python interpreter with spatialdata; skipped otherwise.
store <- file.path(tempdir(), "demo.zarr")
dir.create(store)
tryCatch(
    sdata_export(store, tempfile(fileext = ".tsv")),
    error = function(e) message("spatialdata not available: ", conditionMessage(e)))
#> spatialdata not available: spatialdata_to_punkst.py failed with exit status 1. Last log lines (/tmp/Rtmp3KgYyV/file19882b673b61.tsv.export.log):
#> Traceback (most recent call last):
#>   File "/home/runner/work/_temp/Library/punkstR/python/spatialdata_to_punkst.py", line 23, in <module>
#>     import pandas as pd
#> ModuleNotFoundError: No module named 'pandas'
```
