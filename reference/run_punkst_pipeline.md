# Run the whole pipeline from a SpatialData store

Chains
[`sdata_export()`](https://vjcitn.github.io/punkstR/reference/sdata_export.md),
[`punkst_pts2tiles()`](https://vjcitn.github.io/punkstR/reference/punkst_pts2tiles.md),
[`punkst_tiles2hex()`](https://vjcitn.github.io/punkstR/reference/punkst_tiles2hex.md)
and
[`punkst_topic_model()`](https://vjcitn.github.io/punkstR/reference/punkst_topic_model.md)
in `workdir`. Finished stages are skipped on re-run.

## Usage

``` r
run_punkst_pipeline(
  sdata,
  workdir,
  export = list(),
  pts2tiles = list(),
  tiles2hex = list(),
  topic_model = list(),
  threads = default_threads(),
  bin = NULL,
  python = NULL,
  overwrite = FALSE
)
```

## Arguments

- sdata:

  Path to the SpatialData `.zarr` store.

- workdir:

  Directory for all outputs.

- export, pts2tiles, tiles2hex, topic_model:

  Named lists of arguments for
  [`sdata_export()`](https://vjcitn.github.io/punkstR/reference/sdata_export.md),
  [`punkst_pts2tiles()`](https://vjcitn.github.io/punkstR/reference/punkst_pts2tiles.md),
  [`punkst_tiles2hex()`](https://vjcitn.github.io/punkstR/reference/punkst_tiles2hex.md)
  and
  [`punkst_topic_model()`](https://vjcitn.github.io/punkstR/reference/punkst_topic_model.md),
  e.g.
  `topic_model = list(n_topics = 8, exclude_feature_regex = xenium_control_regex())`.

- threads:

  Threads for the punkst stages.

- bin, python:

  See
  [`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md).

- overwrite:

  Re-run all stages.

## Value

A `punkstRun` object with elements `transcripts`, `tiles`, `hex`,
`model` and `source` (the store, points element and coordinate system
used for export, which
[`sdata_writeback()`](https://vjcitn.github.io/punkstR/reference/sdata_writeback.md)
reuses).

## Details

Each stage takes its options as a list, so every option of the stage
functions is reachable. The pipeline sets these defaults, which override
the stage functions' punkst defaults and are themselves overridden by
your lists: `tile_size = 500`; `hex_grid_dist = 12`, `min_count = 20`,
`randomize = TRUE`, `seed = 1`; `n_topics = 12`, `seed = 1`. `threads`
applies to all three punkst stages.

## Examples

``` r
# Requires the 'punkst' binary and a Python with spatialdata; skipped otherwise.
tryCatch(
    run_punkst_pipeline(file.path(tempdir(), "demo.zarr"), tempfile(),
        topic_model = list(n_topics = 2L)),
    error = function(e) message("pipeline dependencies not available: ",
                                conditionMessage(e)))
#> pipeline dependencies not available: SpatialData store not found: /tmp/RtmpyaloTj/demo.zarr
```
