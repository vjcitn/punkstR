# Match hexagons between two tables by their centre coordinates

The random keys in punkst's outputs are not unique, so hexagons in the
results file and the count file are matched on their (x, y) centres.

## Usage

``` r
match_xy(x, y, ref_x, ref_y, digits = 3L)
```

## Arguments

- x, y:

  Coordinates to look up.

- ref_x, ref_y:

  Reference coordinates, which must be unique.

- digits:

  Decimal places used when comparing coordinates.

## Value

An integer vector, for each `(x, y)` the index into the reference, or
`NA` if not found.

## Examples

``` r
match_xy(x = c(1.001, 5), y = c(2.002, 6), ref_x = c(1, 3), ref_y = c(2, 4))
#> [1] NA NA
```
