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
#> Warning: '/tmp/RtmpNiRhoD/demo.zarr' already exists
res <- tryCatch(sdata_info(store), error = function(e) NULL)
res
#> $spatialdata_version
#> [1] "0.8.0"
#> 
#> $points
#> $points$transcripts
#> $points$transcripts$columns
#> $points$transcripts$columns[[1]]
#> [1] "x"
#> 
#> $points$transcripts$columns[[2]]
#> [1] "y"
#> 
#> $points$transcripts$columns[[3]]
#> [1] "gene"
#> 
#> 
#> $points$transcripts$attrs
#> $points$transcripts$attrs$feature_key
#> [1] "gene"
#> 
#> 
#> $points$transcripts$rows
#> [1] 200
#> 
#> $points$transcripts$max_x
#> [1] 199.442
#> 
#> $points$transcripts$max_y
#> [1] 199.4021
#> 
#> $points$transcripts$transformations
#> $points$transcripts$transformations$global
#> $points$transcripts$transformations$global$type
#> [1] "Identity"
#> 
#> $points$transcripts$transformations$global$repr
#> [1] "Identity "
#> 
#> 
#> 
#> 
#> 
#> $images
#> named list()
#> 
#> $shapes
#> list()
#> 
#> $tables
#> list()
#> 
```
