# Read the hexagon x gene count matrix

Parses the sparse text file written by
[`punkst_tiles2hex()`](https://vjcitn.github.io/punkstR/reference/punkst_tiles2hex.md).

## Usage

``` r
punkst_read_hex(hex)
```

## Arguments

- hex:

  A `punkstHex` object, or the path to the `hex_*.txt` file (the `.json`
  beside it is read for the gene dictionary).

## Value

A list with `units`, a data frame of `key`, `x`, `y`, `nfeat`, `total`
per hexagon, and `counts`, a sparse `dgCMatrix` (hexagons x genes) with
gene names as column names.

## Examples

``` r
d <- tempfile(); dir.create(d)
hex_txt <- file.path(d, "hex_0.txt")
writeLines(c("k1\t1.0\t2.0\t2\t3\t0 2\t1 1", "k2\t3.0\t4.0\t1\t1\t1 1"), hex_txt)
hex_json <- file.path(d, "hex_0.json")
jsonlite::write_json(list(dictionary = list(A0 = 0, B0 = 1)), hex_json, auto_unbox = TRUE)
punkst_read_hex(hex_txt)
#> $units
#>   key x y nfeat total
#> 1  k1 1 2     2     3
#> 2  k2 3 4     1     1
#> 
#> $counts
#> 2 x 2 sparse Matrix of class "dgCMatrix"
#>      A0 B0
#> [1,]  2  1
#> [2,]  .  1
#> 
```
