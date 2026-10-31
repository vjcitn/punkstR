# Read per-hexagon topic probabilities

Read per-hexagon topic probabilities

## Usage

``` r
punkst_read_topics(model)
```

## Arguments

- model:

  A `punkstModel` fitted with `transform = TRUE`, or the path to a
  `*.results.tsv` file.

## Value

A data frame with columns `key`, `x`, `y` and one column per topic
(named as written by punkst). The keys are random and not unique; match
hexagons by position with
[`match_xy()`](https://vjcitn.github.io/punkstR/reference/match_xy.md).

## Examples

``` r
f <- tempfile(fileext = ".results.tsv")
writeLines(c("key\tx\ty\t0\t1", "a\t1.5\t2.5\t0.9\t0.1", "b\t3.5\t4.5\t0.2\t0.8"), f)
punkst_read_topics(f)
#>   key   x   y   0   1
#> 1   a 1.5 2.5 0.9 0.1
#> 2   b 3.5 4.5 0.2 0.8
```
