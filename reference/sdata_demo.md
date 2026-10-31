# Create a small synthetic SpatialData store

Writes a store with one Points element, `transcripts`, of 20 genes in
two spatial regions: the left half is enriched for genes `A0`-`A9`, the
right half for `B0`-`B9`. A two-topic model has real structure to
recover, which makes it a fast fixture for the vignette and for trying
the pipeline (seconds, a few MB). Coordinates live in one
identity-registered coordinate system, `global`.

## Usage

``` r
sdata_demo(
  out,
  n_points = 60000L,
  size = 200,
  n_genes = 20L,
  seed = 0L,
  overwrite = FALSE,
  python = NULL,
  log = tempfile("sdata_demo", fileext = ".log")
)
```

## Arguments

- out:

  Path of the `.zarr` store to create.

- n_points:

  Number of transcripts.

- size:

  Side length of the square field.

- n_genes:

  Number of genes (half `A*`, half `B*`).

- seed:

  Random seed.

- overwrite:

  Replace `out` if it exists.

- python:

  Interpreter override; see
  [`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md).

- log:

  Log file.

## Value

`out`, invisibly.

## Examples

``` r
# Requires a Python interpreter with spatialdata; skipped otherwise.
tryCatch(
    sdata_demo(file.path(tempdir(), "demo.zarr"), n_points = 200L),
    error = function(e) message("spatialdata not available: ", conditionMessage(e)))
#> spatialdata not available: make_synthetic_sdata.py failed with exit status 1. Last log lines (/tmp/Rtmp0mSydy/sdata_demo1a76688ec2b3.log):
#> Traceback (most recent call last):
#>   File "<string>", line 1, in <module>
#>   File "/home/runner/work/_temp/Library/punkstR/python/make_synthetic_sdata.py", line 5, in <module>
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
