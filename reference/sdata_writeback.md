# Write punkst results back into a SpatialData store

Adds one *run* to a SpatialData store: a `shapes` element of circles at
the hexagon centres (`punkst_<run>_hexagons`) and a `table`
(`punkst_<run>`) holding the hexagon x gene counts, the per-hexagon
topic probabilities (`obsm["topics"]`), the gene x topic loadings
(`varm["loadings"]`) and the parameters that produced them
(`uns["punkst"]`). The table is linked to the shapes through
`region`/`instance_id`.

## Usage

``` r
sdata_writeback(
  run,
  hex = NULL,
  sdata = NULL,
  out = NULL,
  in_place = FALSE,
  name = NULL,
  points_key = NULL,
  coordinate_system = "intrinsic",
  overwrite = FALSE,
  python = NULL,
  log = tempfile("writeback", fileext = ".log")
)
```

## Arguments

- run:

  A `punkstRun` from
  [`run_punkst_pipeline()`](https://vjcitn.github.io/punkstR/reference/run_punkst_pipeline.md),
  or a `punkstModel` from
  [`punkst_topic_model()`](https://vjcitn.github.io/punkstR/reference/punkst_topic_model.md)
  (then also give `hex` and `sdata`).

- hex:

  A `punkstHex`; taken from `run` when that is a `punkstRun`.

- sdata:

  The original store; taken from `run` when possible.

- out:

  Path of the sidecar store to create or extend. Default
  `<sdata minus .zarr>_punkst.zarr`. Ignored when `in_place = TRUE`.

- in_place:

  Write into `sdata` itself instead of a sidecar store.

- name:

  Run name used in element names. Default: the model output stem (e.g.
  `hex_12.k12`), which already encodes hexagon spacing and topic count;
  pass your own (e.g. `"k12_alpha0.1"`) when tuning other settings.

- points_key:

  Points element whose transformations the hexagons inherit; taken from
  `run` when possible.

- coordinate_system:

  Coordinate system used for the export (see
  [`sdata_export()`](https://vjcitn.github.io/punkstR/reference/sdata_export.md));
  `"intrinsic"` (default), a name, or `NULL` for the element's only
  system; taken from `run` when possible.

- overwrite:

  Replace an existing run of the same name.

- python:

  Interpreter override; see
  [`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md).

- log:

  Log file.

## Value

The path of the store written to (invisibly), with attributes `run`,
`shapes`, `table`.

## Details

Because element names carry the run name, any number of runs – different
topic counts, hexagon sizes, seeds, priors – can coexist in one store
and be compared with
[`sdata_runs()`](https://vjcitn.github.io/punkstR/reference/sdata_runs.md)
and
[`punkst_compare_runs()`](https://vjcitn.github.io/punkstR/reference/punkst_compare_runs.md).
Writing a run name that already exists is an error unless
`overwrite = TRUE`.

By default results go to a **new sidecar store** (`out`), which holds
only the punkst elements and is read alongside the original. With
`in_place = TRUE` they are added to the store the analysis started from
(this modifies it; the original elements are left untouched).

The hexagon shapes inherit the transformations of the source Points
element when the export used `coordinate_system = "intrinsic"` (so, for
Xenium, the micron-to-pixel scale is preserved and the hexagons overlay
the images and transcripts). If the export used a named coordinate
system the shapes are registered in that system with an identity
transformation.

## Examples

``` r
# Requires a Python interpreter with spatialdata; skipped otherwise.
hex <- punkstHex(workdir = tempdir(),
    files = list(data = tempfile(), meta = tempfile()), params = list())
model <- punkstModel(workdir = tempdir(),
    files = list(model = tempfile(), state = tempfile(), results = tempfile()),
    params = list())
store <- file.path(tempdir(), "demo.zarr")
dir.create(store)
#> Warning: '/tmp/RtmpuGPHhL/demo.zarr' already exists
tryCatch(
    sdata_writeback(model, hex = hex, sdata = store),
    error = function(e) message("spatialdata not available: ", conditionMessage(e)))
#> spatialdata not available: punkst_to_sdata.py write failed with exit status 1. Last log lines (/tmp/RtmpuGPHhL/writeback19ea6e23359d.log):
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
