# Configure the punkst executable and Python interpreter

Records where to find the `punkst` binary and the Python interpreter
used for the SpatialData export script. Values are stored in
`options(punkstR.bin, punkstR.python)`. Nothing is run or validated
here; use
[`check_punkst_setup()`](https://vjcitn.github.io/punkstR/reference/check_punkst_setup.md).

## Usage

``` r
punkst_setup(bin = NULL, python = NULL)
```

## Arguments

- bin:

  Path to the `punkst` binary.

- python:

  Path to a Python interpreter that has `spatialdata` installed.

## Value

The resolved settings, invisibly, as a list.

## Details

Resolution order when an argument is `NULL`: the option, then the
environment variable (`PUNKST`, `PUNKST_PYTHON`), then the `PATH`.

## Examples

``` r
punkst_setup()
```
