# Pipeline stage (abstract parent class)

Common structure of the objects returned by
[`punkst_pts2tiles()`](https://vjcitn.github.io/punkstR/reference/punkst_pts2tiles.md),
[`punkst_tiles2hex()`](https://vjcitn.github.io/punkstR/reference/punkst_tiles2hex.md)
and
[`punkst_topic_model()`](https://vjcitn.github.io/punkstR/reference/punkst_topic_model.md).
`punkstStage` itself is abstract; use the subclasses `punkstTiles`,
`punkstHex` and `punkstModel`.

## Usage

``` r
punkstStage(workdir = character(0), files = list(), params = list())

punkstTiles(workdir = character(0), files = list(), params = list())

punkstHex(workdir = character(0), files = list(), params = list())

punkstModel(workdir = character(0), files = list(), params = list())
```

## Arguments

- workdir:

  Directory holding the stage's outputs.

- files:

  Named list of output file paths. Required names: `punkstTiles` `tsv`,
  `index`, `features`; `punkstHex` `data`, `meta`; `punkstModel`
  `model`, `state` (plus `results` and `pseudobulk` when fitted with
  `transform = TRUE`).

- params:

  Named list of the parameters that produced the outputs. These also
  drive the skip-if-up-to-date manifest and are recorded by
  [`sdata_writeback()`](https://vjcitn.github.io/punkstR/reference/sdata_writeback.md).

## Value

An object of the respective subclass.

## Examples

``` r
tiles <- punkstTiles(workdir = tempdir(),
    files = list(tsv = "tiled.tsv", index = "tiled.index", features = "tiled.features.tsv"),
    params = list(tile_size = 500))
tiles
#> <punkstTiles> in /tmp/RtmploZoDv
#>   tsv       tiled.tsv
#>   index     tiled.index
#>   features  tiled.features.tsv
```
