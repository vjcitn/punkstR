# Summarise a SpatialData store

Runs the bundled `sdata_info.py` with
[`system2()`](https://rdrr.io/r/base/system2.html) and reads the JSON it
writes. Useful for checking which coordinate system holds microns before
exporting.

## Usage

``` r
sdata_info(
  sdata,
  points_key = "transcripts",
  python = NULL,
  log = tempfile("sdata_info", fileext = ".log")
)
```

## Arguments

- sdata:

  Path to the SpatialData `.zarr` store.

- points_key:

  Points element for which row count and coordinate extent are computed
  (this can take a while for large stores). `NULL` computes it for every
  points element.

- python:

  Interpreter override; see
  [`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md).

- log:

  Log file for the script's output.

## Value

A list with `points` (per element: `columns`, `attrs`, `rows`, `max_x`,
`max_y`, `transformations`), `images` (pixel sizes at full resolution),
`shapes`, `tables` and `spatialdata_version`.

## Examples

``` r
store <- file.path(tempdir(), "demo.zarr")
dir.create(store)
#> Warning: '/tmp/RtmpttWHGi/demo.zarr' already exists
res <- tryCatch(sdata_info(store), error = function(e) NULL)
res
#> NULL
```
