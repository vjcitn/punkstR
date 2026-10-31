# Getting started with punkstR

punkstR runs the [punkst](https://github.com/Yichen-Si/punkst)
pixel-level factor-analysis pipeline on a SpatialData store, entirely
from R. It calls the `punkst` binary and a small export script with
[`system2()`](https://rdrr.io/r/base/system2.html); nothing is imported
into R from Python and punkstR never builds or installs punkst (see the
README for a build recipe).

This vignette uses a small synthetic store, so it runs in under a
minute. A real-data walkthrough (a Xenium breast cancer section with 42
million transcripts) is installed under
`system.file("largedemos", package = "punkstR")`.

The code is evaluated only when a `punkst` binary and a Python with
`spatialdata` are found (`PUNKST`, `PUNKST_PYTHON`, or on the `PATH`);
otherwise it is shown but not run.

## Check the setup

``` r

library(punkstR)
cfg <- check_punkst_setup()
```

    punkst binary : OK      /home/runner/work/punkstR/punkstR/punkst-0.1.2-linux-x86_64-glibc2.28/bin/punkst
    python/sdata  : MISSING /opt/hostedtoolcache/Python/3.12.15/x64/bin/python
    * /opt/hostedtoolcache/Python/3.12.15/x64/bin/python could not import spatialdata and zarr. Output: Traceback (most recent call last): |   File "<string>", line 1, in <module> | ModuleNotFoundError: No module named 'spatialdata'

``` r

can_run <- cfg@bin_ok && cfg@python_ok
knitr::opts_chunk$set(eval = can_run, fig.width = 7, fig.height = 4, dpi = 100)
```

[`check_punkst_setup()`](https://vjcitn.github.io/punkstR/reference/check_punkst_setup.md)
returns a `punkstConfig` object. It lists what is missing and never
installs anything.

## A synthetic store

[`sdata_demo()`](https://vjcitn.github.io/punkstR/reference/sdata_demo.md)
writes a SpatialData store with 60,000 transcripts of 20 genes: genes
`A0`-`A9` are enriched in the left half of the field and `B0`-`B9` in
the right. A two-topic model has something real to find.

``` r

work <- tempfile("punkstR_demo_")
dir.create(work)
zarr <- sdata_demo(file.path(work, "demo.zarr"))
info <- sdata_info(zarr)
info$points$transcripts$rows
names(info$points$transcripts$transformations)
```

## Run the pipeline

[`run_punkst_pipeline()`](https://vjcitn.github.io/punkstR/reference/run_punkst_pipeline.md)
exports the transcripts, tiles them (`pts2tiles`), aggregates them into
hexagons (`tiles2hex`) and fits a topic model (`topic-model`). Options
for each stage go in a named list; everything else takes punkst’s
defaults. Stages whose inputs and parameters have not changed are
skipped on re-runs.

``` r

run2 <- run_punkst_pipeline(
    zarr, file.path(work, "out"), threads = 2,
    export = list(coordinate_system = NULL),
    pts2tiles = list(tile_size = 100),
    tiles2hex = list(min_count = 5),
    topic_model = list(n_topics = 2, n_epochs = 5, min_count_train = 5))
run2
```

The result is a `punkstRun` object whose properties (`run2@hex`,
`run2@model`, …) are stage objects holding file paths and the parameters
used.

## Read the results

``` r

m <- punkst_read_model(run2@model)          # genes x topics
round(head(m[order(rownames(m)), ], 4))
topics <- punkst_read_topics(run2@model)    # one row per hexagon
head(topics, 3)
```

Each topic should collect one family of genes:

``` r

frac_a <- vapply(as.data.frame(m), function(v)
    sum(v[startsWith(rownames(m), "A")]) / sum(v), 0)
round(frac_a, 2)
```

and the topics should occupy different halves of the field:

``` r

tp <- topics[, -(1:3)]
top <- max.col(as.matrix(tp), "first")
plot(topics$x, topics$y, col = c("#d95f02", "#1b9e77")[top], pch = 15, cex = 0.5,
     asp = 1, xlab = "x", ylab = "y", main = "Dominant topic per hexagon")
```

## Try other settings and compare

Different tuning choices go in the same work directory; output names
carry the hexagon spacing and topic count, so runs do not overwrite each
other.

``` r

run3 <- run_punkst_pipeline(
    zarr, file.path(work, "out"), threads = 2,
    export = list(coordinate_system = NULL),
    pts2tiles = list(tile_size = 100),
    tiles2hex = list(min_count = 5),
    topic_model = list(n_topics = 3, n_epochs = 5, min_count_train = 5))
cmp <- punkst_compare_runs(run2, run3)
cmp$pairs
cmp$agreement
```

[`punkst_compare_runs()`](https://vjcitn.github.io/punkstR/reference/punkst_compare_runs.md)
pairs each topic of one fit with its most similar topic of the other
(cosine similarity of gene loadings) and reports how often hexagons keep
their pairing.

## Write results back into a SpatialData store

[`sdata_writeback()`](https://vjcitn.github.io/punkstR/reference/sdata_writeback.md)
adds a run to a store as a `shapes` element of hexagons and a `table`
with counts, topic probabilities, gene loadings and the parameters that
produced them. By default it writes a new sidecar store; use
`in_place = TRUE` to add to the original.

``` r

side <- file.path(work, "demo_punkst.zarr")
sdata_writeback(run2, out = side)
sdata_writeback(run3, out = side)
runs <- sdata_runs(side)
runs[, c("run", "n_hexagons", "n_topics", "hex_size")]
```

Both runs now live side by side in one store, ready to be read with
`spatialdata`, `anndata` or other SpatialData tooling.
