# List the punkst runs stored in a SpatialData store

List the punkst runs stored in a SpatialData store

## Usage

``` r
sdata_runs(sdata, python = NULL, log = tempfile("runs", fileext = ".log"))
```

## Arguments

- sdata:

  Path to a store written by
  [`sdata_writeback()`](https://vjcitn.github.io/punkstR/reference/sdata_writeback.md).

- python:

  Interpreter override; see
  [`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md).

- log:

  Log file.

## Value

A data frame with one row per run: `run`, `table`, `n_hexagons`,
`n_genes`, `n_topics`, `hex_size` and a list column `params` holding the
recorded `tiles2hex` and `topic_model` parameters.

## Examples

``` r
# Requires a Python interpreter with spatialdata; skipped otherwise.
store <- file.path(tempdir(), "demo.zarr")
dir.create(store)
#> Warning: '/tmp/RtmpIgtxaz/demo.zarr' already exists
tryCatch(
    sdata_runs(store),
    error = function(e) message("spatialdata not available: ", conditionMessage(e)))
#> spatialdata not available: punkst_to_sdata.py list failed with exit status 1. Last log lines (/tmp/RtmpIgtxaz/runs1a533cefab4c.log):
#> Traceback (most recent call last):
#>   File "/home/runner/work/_temp/Library/punkstR/python/punkst_to_sdata.py", line 16, in <module>
#>     import numpy as np
#> ModuleNotFoundError: No module named 'numpy'
```
