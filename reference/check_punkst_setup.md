# Check that the required tools are available

Looks for the `punkst` binary and a Python interpreter with
`spatialdata` and reports what was found. It runs each tool once
(`punkst --help` and a short `python -c` import) but never installs or
builds anything. If the binary is missing, the message points to the
build recipe.

## Usage

``` r
check_punkst_setup(bin = NULL, python = NULL, quiet = FALSE)
```

## Arguments

- bin, python:

  Optional overrides; see
  [`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md).

- quiet:

  If `FALSE`, print a summary.

## Value

A
[punkstConfig](https://vjcitn.github.io/punkstR/reference/punkstConfig.md)
object with properties `bin`, `python`, `bin_ok`, `python_ok`,
`spatialdata_version`, `zarr_version`, `notes`.

## Examples

``` r
cfg <- check_punkst_setup(quiet = TRUE)
cfg
#> punkst binary : OK      /home/runner/work/punkstR/punkstR/punkst-0.1.2-linux-x86_64-glibc2.28/bin/punkst 
#> python/sdata  : OK      /opt/punkst-venv/bin/python-preload (spatialdata 0.8.0, zarr 3.4.2) 
```
