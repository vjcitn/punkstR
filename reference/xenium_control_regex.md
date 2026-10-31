# Regular expression for Xenium control features

Matches the control probes and codewords in Xenium transcript tables
(`antisense_*`, `NegControl*`, `BLANK_*`, `UnassignedCodeword*`). Pass
it as `exclude_feature_regex` to
[`punkst_topic_model()`](https://vjcitn.github.io/punkstR/reference/punkst_topic_model.md).

## Usage

``` r
xenium_control_regex()
```

## Value

A character string.

## Examples

``` r
xenium_control_regex()
#> [1] "^(antisense_|NegControl|BLANK_|UnassignedCodeword)"
grepl(xenium_control_regex(), c("BLANK_0001", "A0"))
#> [1]  TRUE FALSE
```
