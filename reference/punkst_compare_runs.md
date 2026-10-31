# Compare two punkst runs

Topics have no fixed identity between fits, so each topic of `a` is
paired with its most similar topic of `b` (cosine similarity of the gene
loadings, over genes present in both; greedy one-to-one matching, best
pairs first). When both runs use the same hexagon grid the per-hexagon
top-topic assignments are also compared under that pairing.

## Usage

``` r
punkst_compare_runs(a, b)
```

## Arguments

- a, b:

  Runs to compare: `punkstRun`, `punkstModel`, or model file paths.

## Value

A list with `pairs` (data frame: `topic_a`, `topic_b`, `cosine`),
`similarity` (full topic x topic cosine matrix), `n_shared_genes`, and,
when the grids match, `agreement` (fraction of shared hexagons whose top
topics are paired) and `n_shared_hexagons`.

## Details

Works on files, so it needs no Python: give `punkstRun`/`punkstModel`
objects or paths to `*.model.tsv`.

## Examples

``` r
a <- tempfile(fileext = ".model.tsv")
b <- tempfile(fileext = ".model.tsv")
writeLines(c("gene\t0\t1", "A0\t10\t1", "B0\t1\t10"), a)
writeLines(c("gene\t0\t1", "A0\t9\t1", "B0\t1\t9"), b)
# Bare model paths have no matching *.results.tsv, so only the topic
# similarity (not the per-hexagon agreement) can be computed here.
cmp <- punkst_compare_runs(a, b)
cmp$pairs
#>   topic_a topic_b    cosine
#> 1       1       1 0.9999396
#> 2       0       0 0.9999396
```
