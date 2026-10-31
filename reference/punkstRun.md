# One pipeline run

The result of
[`run_punkst_pipeline()`](https://vjcitn.github.io/punkstR/reference/run_punkst_pipeline.md):
the exported transcripts file, the three stage objects, and where the
data came from (needed by
[`sdata_writeback()`](https://vjcitn.github.io/punkstR/reference/sdata_writeback.md)
to align results with the source store).

## Usage

``` r
punkstRun(transcripts, tiles, hex, model, source)
```

## Arguments

- transcripts:

  Path to the exported transcripts file.

- tiles, hex, model:

  The `punkstTiles`, `punkstHex` and `punkstModel` stage objects.

- source:

  List with `sdata` (store path), `points_key` and `coordinate_system`
  (as used for export; may be `NULL`).

## Value

A `punkstRun` object.

## Examples

``` r
tiles <- punkstTiles(workdir = tempdir(),
    files = list(tsv = "t.tsv", index = "t.index", features = "t.features.tsv"),
    params = list())
hex <- punkstHex(workdir = tempdir(),
    files = list(data = "hex.txt", meta = "hex.json"), params = list())
model <- punkstModel(workdir = tempdir(),
    files = list(model = "m.model.tsv", state = "m.state"), params = list())
run <- punkstRun(transcripts = "transcripts.tsv", tiles = tiles, hex = hex,
    model = model, source = list(sdata = "demo.zarr", points_key = "transcripts"))
run
#> <punkstRun>
#>   source     : demo.zarr 
#>   transcripts: transcripts.tsv 
#> <punkstTiles> in /tmp/RtmprHvtcE
#>   tsv       t.tsv
#>   index     t.index
#>   features  t.features.tsv
#> <punkstHex> in /tmp/RtmprHvtcE
#>   data      hex.txt
#>   meta      hex.json
#> <punkstModel> in /tmp/RtmprHvtcE
#>   model     m.model.tsv
#>   state     m.state
```
