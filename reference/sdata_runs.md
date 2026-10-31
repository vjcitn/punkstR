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
#> Warning: '/tmp/RtmpttWHGi/demo.zarr' already exists
tryCatch(
    sdata_runs(store),
    error = function(e) message("spatialdata not available: ", conditionMessage(e)))
#> spatialdata not available: punkst_to_sdata.py list failed with exit status 1. Last log lines (/tmp/RtmpttWHGi/runs1a704ab78dea.log):
#> Traceback (most recent call last):
#>   File "/home/runner/work/_temp/Library/punkstR/python/punkst_to_sdata.py", line 17, in <module>
#>     import pandas as pd
#>   File "/opt/punkst-venv/lib/python3.12/site-packages/pandas/__init__.py", line 44, in <module>
#>     import pandas.core.config_init  # pyright: ignore[reportUnusedImport] # noqa: F401
#>     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#>   File "/opt/punkst-venv/lib/python3.12/site-packages/pandas/core/config_init.py", line 31, in <module>
#>     from pandas.errors import Pandas4Warning
#>   File "/opt/punkst-venv/lib/python3.12/site-packages/pandas/errors/__init__.py", line 8, in <module>
#>     import ctypes
#>   File "/opt/hostedtoolcache/Python/3.12.15/x64/lib/python3.12/ctypes/__init__.py", line 8, in <module>
#>     from _ctypes import Union, Structure, Array
#> ImportError: /opt/hostedtoolcache/Python/3.12.15/x64/lib/python3.12/lib-dynload/_ctypes.cpython-312-x86_64-linux-gnu.so: undefined symbol: _PyErr_SetLocaleString
```
