# Large demonstrations

These documents need data or compute that do not belong in a package vignette,
so they are installed with punkstR but are not built as vignettes.

- `xenium-breast.qmd`: pixel-level factor analysis of a Xenium breast cancer
  section (about 42 million transcripts). Needs `PUNKSTR_DEMO_ZARR` (the
  SpatialData store), a built `punkst`, a Python with `spatialdata` >= 0.7 and
  the Quarto command line tool. `PUNKSTR_DEMO_WORKDIR` keeps the ~2 GB of
  intermediate files between renders. The rendered HTML is about 36 MB.

Render from R:

```r
f <- system.file("largedemos", "xenium-breast.qmd", package = "punkstR")
quarto::quarto_render(f)   # renders next to the file; copy it somewhere writable first
```

For a quick, self-contained walkthrough see `vignette("punkstR")`.
