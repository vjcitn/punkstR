# Read the fitted gene x topic matrix

Read the fitted gene x topic matrix

## Usage

``` r
punkst_read_model(model)
```

## Arguments

- model:

  A `punkstModel` from
  [`punkst_topic_model()`](https://vjcitn.github.io/punkstR/reference/punkst_topic_model.md),
  or the path to a `*.model.tsv` file.

## Value

A numeric matrix with genes in rows and topics in columns (column names
are the topic indices as written by punkst). Entries are the
pseudo-counts of each gene assigned to each topic.

## Examples

``` r
f <- tempfile(fileext = ".model.tsv")
writeLines(c("gene\t0\t1", "A0\t10\t1", "B0\t1\t10"), f)
punkst_read_model(f)
#>     0  1
#> A0 10  1
#> B0  1 10
```
