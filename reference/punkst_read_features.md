# Read the feature table written by pts2tiles

Read the feature table written by pts2tiles

## Usage

``` r
punkst_read_features(tiles)
```

## Arguments

- tiles:

  A `punkstTiles` object, or the path to `tiled.features.tsv`.

## Value

A data frame with `feature` and `count`.

## Examples

``` r
f <- tempfile(fileext = ".features.tsv")
writeLines(c("A0\t120", "B0\t95"), f)
punkst_read_features(f)
#>   feature count
#> 1      A0   120
#> 2      B0    95
```
