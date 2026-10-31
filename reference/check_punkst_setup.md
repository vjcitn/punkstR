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
#> python/sdata  : MISSING /opt/punkst-venv/bin/python 
#> * /opt/punkst-venv/bin/python could not import spatialdata and zarr. Output:   File "/opt/hostedtoolcache/Python/3.12.15/x64/lib/python3.12/ctypes/__init__.py", line 8, in <module> |     from _ctypes import Union, Structure, Array | ImportError: /opt/hostedtoolcache/Python/3.12.15/x64/lib/python3.12/lib-dynload/_ctypes.cpython-312-x86_64-linux-gnu.so: undefined symbol: _PyErr_SetLocaleString
```
