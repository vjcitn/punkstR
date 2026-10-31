# Tile a transcript file (`punkst pts2tiles`)

Splits a delimited point file into spatial tiles and writes an index.
Covers the standard mode of `punkst pts2tiles`; the
`--tile-op-factor-tsv` mode (converting factor-probability output, with
`--binary-out`, `--K`, `--pixel-res`, `--feature-dict`) is not wrapped.
Defaults are punkst's own, and an option is passed only when it differs
from its default, except that the column indices default to 0, 1 and 2
(x, y, feature), the layout written by
[`sdata_export()`](https://vjcitn.github.io/punkstR/reference/sdata_export.md),
where punkst has no default.

## Usage

``` r
punkst_pts2tiles(
  tsv,
  workdir,
  tile_size,
  icol_x = 0L,
  icol_y = 1L,
  icol_feature = 2L,
  icol_z = NULL,
  icol_int = NULL,
  csv = FALSE,
  keep_quotes = NULL,
  skip = 0L,
  skip_last_is_header = FALSE,
  scale = 1,
  scale_x = NULL,
  scale_y = NULL,
  scale_z = NULL,
  digits = 2L,
  include_cols = NULL,
  exclude_cols = NULL,
  tile_buffer = 1000L,
  batch_size = 10000L,
  temp_dir = NULL,
  threads = 1L,
  verbose = 1000000L,
  debug = 0L,
  bin = NULL,
  overwrite = FALSE
)
```

## Arguments

- tsv:

  Input delimited file (`--in-tsv`), e.g. from
  [`sdata_export()`](https://vjcitn.github.io/punkstR/reference/sdata_export.md).

- workdir:

  Directory for outputs, logs and the manifest.

- tile_size:

  Tile size in the input's coordinate units (`--tile-size`). Required.

- icol_x, icol_y, icol_feature:

  0-based columns of x, y and feature (`--icol-x`, `--icol-y`,
  `--icol-feature`). `icol_feature = NULL` omits the feature column and
  the feature dictionary output.

- icol_z:

  Optional 0-based z column (`--icol-z`).

- icol_int:

  Optional 0-based integer-value (count) columns (`--icol-int`).

- csv:

  Treat the input as CSV (`--csv`); punkst otherwise infers it from the
  file extension.

- keep_quotes:

  0-based columns to keep quoted in CSV output (`--keep-quotes`).

- skip:

  Number of input lines to skip (`--skip`).

- skip_last_is_header:

  Treat the last skipped line as the header (`--skip-last-is-header`).
  Lines starting with `#` at the top are detected automatically, so this
  is not needed for
  [`sdata_export()`](https://vjcitn.github.io/punkstR/reference/sdata_export.md)
  output.

- scale:

  Uniform coordinate scale factor (`--scale`).

- scale_x, scale_y, scale_z:

  Per-axis scale factors that override `scale` (`--scale-x`,
  `--scale-y`, `--scale-z`).

- digits:

  Precision of rewritten coordinates when scaling is applied
  (`--digits`).

- include_cols, exclude_cols:

  0-based columns to keep or drop in the tiled output (`--include-cols`,
  `--exclude-cols`; mutually exclusive). The column positions in the
  tiled file then differ from the input, so pass matching `icol_*` to
  [`punkst_tiles2hex()`](https://vjcitn.github.io/punkstR/reference/punkst_tiles2hex.md).

- tile_buffer:

  Buffer lines per tile per thread (`--tile-buffer`).

- batch_size:

  Batch size in lines for gzipped or streamed input (`--batch-size`).

- temp_dir:

  Directory for temporary files (`--temp-dir`); default is
  `<workdir>/tmp_pts2tiles`.

- threads:

  Number of threads (`--threads`).

- verbose, debug:

  Verbosity and debug level (`--verbose`, `--debug`).

- bin:

  Path to `punkst`; see
  [`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md).

- overwrite:

  Re-run even if up to date.

## Value

A `punkstTiles` stage object with the output `files` (`tsv`, `index`,
`coord_range`, and `features` when a feature column is given).

## Examples

``` r
# Requires the 'punkst' binary (see check_punkst_setup()); skipped otherwise.
tsv <- tempfile(fileext = ".tsv")
writeLines(c("1\t1\tA0", "2\t2\tB0"), tsv)
tryCatch(
    punkst_pts2tiles(tsv, tempfile(), tile_size = 500),
    error = function(e) message("punkst not available: ", conditionMessage(e)))
#> [punkstR] pts2tiles: running
#> [punkstR] pts2tiles: done in 0 s
#> <punkstTiles> in /tmp/RtmpUztHlu/file19d5226bde07
#>   tsv       /tmp/RtmpUztHlu/file19d5226bde07/tiled.tsv
#>   index     /tmp/RtmpUztHlu/file19d5226bde07/tiled.index
#>   coord_range /tmp/RtmpUztHlu/file19d5226bde07/tiled.coord_range.tsv
#>   features  /tmp/RtmpUztHlu/file19d5226bde07/tiled.features.tsv
```
