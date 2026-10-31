# Resolved punkst configuration

Holds the punkst executable and Python interpreter that were resolved
(argument, then option, then environment variable, then `PATH`; see
[`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md))
together with what checking them found. It is created by
[`check_punkst_setup()`](https://vjcitn.github.io/punkstR/reference/check_punkst_setup.md);
you would rarely construct one yourself. A `punkstConfig` can be passed
wherever a `bin` or `python` argument is accepted, in which case the
corresponding path is used.

## Usage

``` r
punkstConfig(
  bin = character(0),
  python = character(0),
  bin_ok = logical(0),
  python_ok = logical(0),
  spatialdata_version = character(0),
  zarr_version = character(0),
  notes = character(0)
)
```

## Arguments

- bin:

  Path to the punkst executable, or `NA_character_` if none found.

- python:

  Path to the Python interpreter, or `NA_character_`.

- bin_ok:

  `TRUE` if `bin` exists, is executable and prints punkst's help text.

- python_ok:

  `TRUE` if `python` can import `spatialdata` and `zarr`.

- spatialdata_version, zarr_version:

  Versions reported by the interpreter, `NA_character_` if unavailable.

- notes:

  Character vector of actionable messages about what is missing (never
  installs anything; points to the build recipe).

## Value

A `punkstConfig` object; use `@` to read its properties.

## Examples

``` r
cfg <- punkstConfig(bin = NA_character_, python = NA_character_,
    bin_ok = FALSE, python_ok = FALSE,
    spatialdata_version = NA_character_, zarr_version = NA_character_,
    notes = "example only")
cfg
#> punkst binary : MISSING NA 
#> python/sdata  : MISSING NA 
#> * example only
```
