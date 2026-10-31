# Pool transcripts into hexagons (`punkst tiles2hex`)

Aggregates tiled points into hexagonal units (or 3D BCC units) and
writes a sparse count file plus JSON metadata. Defaults are punkst's own
and an option is passed only when it differs. Column indices default to
those used when tiling (`tiles@params`).

## Usage

``` r
punkst_tiles2hex(
  tiles,
  hex_grid_dist = NULL,
  hex_size = NULL,
  bcc_grid_dist = NULL,
  bcc_size = NULL,
  icol_x = tiles@params$icol_x,
  icol_y = tiles@params$icol_y,
  icol_feature = tiles@params$icol_feature,
  icol_z = NULL,
  icol_int = NULL,
  feature_dict = tiles@files$features,
  min_count = NULL,
  bounding_boxes = NULL,
  anchor_files = NULL,
  radius = NULL,
  ignore_background = FALSE,
  idf_q = 95,
  idf_power = 0.3,
  idf_min = 0.1,
  idf_max = 5,
  randomize = FALSE,
  seed = -1L,
  sort_mem = NULL,
  use_internal_sort = FALSE,
  out_prefix = NULL,
  temp_dir = NULL,
  threads = 1L,
  verbose = 1000000L,
  debug = 0L,
  bin = NULL,
  overwrite = FALSE
)
```

## Arguments

- tiles:

  A `punkstTiles` object from
  [`punkst_pts2tiles()`](https://vjcitn.github.io/punkstR/reference/punkst_pts2tiles.md).

- hex_grid_dist, hex_size:

  Hexagon centre-to-centre distance (`--hex-grid-dist`) or side length
  (`--hex-size`).

- bcc_grid_dist, bcc_size:

  BCC lattice spacing (`--bcc-grid-dist`) or size (`--bcc-size`) for 3D
  aggregation.

- icol_x, icol_y, icol_feature:

  0-based columns in the tiled file (`--icol-x`, `--icol-y`,
  `--icol-feature`); default to the values used in
  [`punkst_pts2tiles()`](https://vjcitn.github.io/punkstR/reference/punkst_pts2tiles.md).

- icol_z:

  0-based z column, which enables 3D aggregation (`--icol-z`).

- icol_int:

  0-based integer-value columns (`--icol-int`).

- feature_dict:

  Feature name list for non-integer feature columns (`--feature-dict`);
  defaults to the tiling stage's feature file.

- min_count:

  Minimum count per integer column for a unit to be kept, combined with
  OR (`--min-count`); punkst's default keeps units with at least 1.

- bounding_boxes:

  Rectangular regions `(xmin ymin xmax ymax)*` to restrict to
  (`--bounding-boxes`).

- anchor_files, radius, ignore_background:

  Aggregate around anchor points instead of a grid (`--anchor-files`,
  `--radius`, `--ignore-background`).

- idf_q, idf_power, idf_min, idf_max:

  Parameters of the capped IDF feature weights (`--idf-q`,
  `--idf-power`, `--idf-min`, `--idf-max`).

- randomize:

  Randomise the output order (`--randomize`). punkst does not by
  default; online topic-model training generally benefits from it.

- seed:

  Seed for the randomised output keys (`--seed`); `-1` draws a random
  one.

- sort_mem:

  Memory for sorting with K, M or G units (`--sort-mem`).

- use_internal_sort:

  Use punkst's internal sort instead of the system `sort`
  (`--use-internal-sort`).

- out_prefix:

  Output stem; default `<workdir>/hex_<grid size>`.

- temp_dir:

  Directory for temporary files; default `<workdir>/tmp_tiles2hex`.

- threads:

  Number of threads (`--threads`).

- verbose, debug:

  Verbosity and debug level.

- bin:

  Path to `punkst`; see
  [`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md).

- overwrite:

  Re-run even if up to date.

## Value

A `punkstHex` stage object; `files$data`, `files$meta` and
`files$features` feed
[`punkst_topic_model()`](https://vjcitn.github.io/punkstR/reference/punkst_topic_model.md).

## Details

Give exactly the grid you need: `hex_grid_dist` or `hex_size` for 2D, or
`bcc_grid_dist` or `bcc_size` (with `icol_z`) for 3D. punkst has no
default size.

## Examples

``` r
# Requires the 'punkst' binary (see check_punkst_setup()); skipped otherwise.
tiles <- punkstTiles(workdir = tempdir(),
    files = list(tsv = tempfile(), index = tempfile(), features = tempfile()),
    params = list(icol_x = 0L, icol_y = 1L, icol_feature = 2L))
tryCatch(
    punkst_tiles2hex(tiles, hex_size = 50),
    error = function(e) message("punkst not available: ", conditionMessage(e)))
#> [punkstR] tiles2hex_hexsize_50: running
#> punkst not available: punkst tiles2hex failed with exit status 134. Last log lines (/tmp/Rtmp0mSydy/tiles2hex_hexsize_50.log):
#>     --in-tsv [/tmp/Rtmp0mSydy/file1a763caa5063],
#>     --in-index [/tmp/Rtmp0mSydy/file1a766db34d75], --icol-x [0], --icol-y [1],
#>     --icol-z [-1], --icol-feature [2],
#>     --feature-dict [/tmp/Rtmp0mSydy/file1a7618c5528a], --icol-int,
#>     --bounding-boxes, --anchor-files, --radius, --hex-size [50],
#>     --hex-grid-dist [-1], --bcc-size [-1], --bcc-grid-dist [-1],
#>     --temp-dir [/tmp/Rtmp0mSydy/tmp_tiles2hex], --seed [-1], --threads [1],
#>     --out [/tmp/Rtmp0mSydy/hexsize_50.txt], --randomize [false], --sort-mem,
#>     --use-internal-sort [false], --idf-q [95], --idf-power [0.3], --idf-min [0.1],
#>     --idf-max [5], --min-count, --ignore-background [false], --verbose [1000000],
#>     --debug [0]
#> 
#> terminate called after throwing an instance of 'std::runtime_error'
#>   what():  [2026-10-31 14:56:55] ERROR: Error opening index file: /tmp/Rtmp0mSydy/file1a766db34d75
#> Aborted (core dumped)
```
