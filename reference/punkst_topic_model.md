# Fit a topic model to hexagon data (`punkst topic-model`)

Exposes the options of `punkst topic-model` that apply to hexagon input
(the 10X input options and `--dataset-id` are not applicable). Defaults
are punkst's own, taken from its source (`script/fit_lda.cpp`) and docs,
and an option is passed on the command line only when it differs from
its default, so punkst's behaviour is unchanged unless you ask for it.
Options whose default is "unset" (for example `alpha`, which punkst sets
to `1/K`) are `NULL`.

## Usage

``` r
punkst_topic_model(
  hex,
  n_topics = NULL,
  n_epochs = 1L,
  out_prefix = NULL,
  seed = -1L,
  threads = 0L,
  minibatch_size = 512L,
  min_count_train = 20L,
  min_count_per_feature = 1L,
  include_feature_regex = NULL,
  exclude_feature_regex = NULL,
  icol_weight = -1L,
  default_weight = -1,
  modal = 0L,
  kappa = 0.7,
  tau0 = 10,
  alpha = NULL,
  eta = NULL,
  max_iter = 100L,
  mean_change_tol = 0.001,
  reproducible_init = FALSE,
  model_prior = NULL,
  prior_scale = NULL,
  prior_scale_rel = NULL,
  projection_only = FALSE,
  fit_background = FALSE,
  background_prior = NULL,
  background_init_scale = 0.5,
  background_prevalence_power = 0,
  fix_background = FALSE,
  bg_fraction_prior_a0 = 2,
  bg_fraction_prior_b0 = 8,
  warm_start_epochs = 0.5,
  adaptive_topics = FALSE,
  min_topic_mean = 1e-05,
  adaptive_refit_epochs = 1L,
  transform = TRUE,
  sort_topics = FALSE,
  topk_only = NULL,
  residuals = FALSE,
  feature_residuals = FALSE,
  feature_diagnostics_cheap = FALSE,
  unit_diagnostics_similarity = FALSE,
  pseudobulk_all_features = FALSE,
  count_cache = "auto",
  count_cache_memory_budget = "1G",
  temp_dir = NULL,
  debug = 0L,
  verbose = 0L,
  bin = NULL,
  overwrite = FALSE
)
```

## Arguments

- hex:

  A `punkstHex` object from
  [`punkst_tiles2hex()`](https://vjcitn.github.io/punkstR/reference/punkst_tiles2hex.md);
  it supplies `--in-data`, `--in-meta` and `--features`.

- n_topics:

  Number of topics (`--n-topics`). Required unless `model_prior` is
  given.

- n_epochs:

  Training passes over the data (`--n-epochs`).

- out_prefix:

  Output prefix; default `<workdir>/<hex stem>.k<n_topics>`.

- seed:

  Random seed (`--seed`). The default `-1` lets punkst draw a random
  seed, so runs are not reproducible unless you set one.

- threads:

  Threads (`--threads`); `0` lets punkst (TBB) choose.

- minibatch_size:

  Minibatch size (`--minibatch-size`).

- min_count_train:

  Minimum total count for a unit to be trained on (`--min-count-train`).

- min_count_per_feature:

  Minimum total count for a feature to be kept
  (`--min-count-per-feature`).

- include_feature_regex, exclude_feature_regex:

  Regular expressions selecting features (`--include-feature-regex`,
  `--exclude-feature-regex`); e.g.
  [`xenium_control_regex()`](https://vjcitn.github.io/punkstR/reference/xenium_control_regex.md).

- icol_weight:

  0-based column of per-feature weights in the feature file
  (`--icol-weight`); `-1` disables weighting.

- default_weight:

  Weight for model or prior features missing from the feature file
  (`--default-weight`); negative drops them.

- modal:

  Modality index (`--modal`).

- kappa, tau0:

  Online learning decay rate and offset (`--kappa`, `--tau0`).

- alpha, eta:

  Document-topic and topic-word priors (`--alpha`, `--eta`); `NULL` uses
  `1/K`.

- max_iter, mean_change_tol:

  Per-document inference limits (`--max-iter`, `--mean-change-tol`).

- reproducible_init:

  Deterministic per-document initialisation, slower
  (`--reproducible-init`).

- model_prior:

  File with an initial model matrix for continued training
  (`--model-prior`).

- prior_scale, prior_scale_rel:

  Scaling of the prior model (`--prior-scale`, `--prior-scale-rel`; the
  relative one wins).

- projection_only:

  Transform with `model_prior` and do not train (`--projection-only`).

- fit_background:

  Fit a background component in addition to the topics
  (`--fit-background`).

- background_prior:

  File with a background prior vector (`--background-prior`).

- background_init_scale, background_prevalence_power, fix_background,
  bg_fraction_prior_a0, bg_fraction_prior_b0, warm_start_epochs:

  Background model settings (`--background-init-scale`,
  `--background-prevalence-power`, `--fix-background`,
  `--bg-fraction-prior-a0`, `--bg-fraction-prior-b0`,
  `--warm-start-epochs`).

- adaptive_topics:

  Treat `n_topics` as an upper bound, prune unused topics and refit
  (`--adaptive-topics`).

- min_topic_mean, adaptive_refit_epochs:

  Adaptive fitting settings (`--min-topic-mean`,
  `--adaptive-refit-epochs`).

- transform:

  Transform the data to topic space after fitting (`--transform`);
  needed for the results and pseudobulk files.

- sort_topics:

  Sort topics by weight (`--sort-topics`).

- topk_only:

  If set, write only the top-k topics per unit to the results file
  (`--topk-only`).

- residuals, feature_residuals, feature_diagnostics_cheap,
  unit_diagnostics_similarity, pseudobulk_all_features:

  Diagnostic and output options (flags of the same names).

- count_cache, count_cache_memory_budget:

  Repeated-pass count cache (`--count-cache`: `"off"`, `"on"`, `"auto"`;
  `--count-cache-memory-budget` with K, M or G suffixes).

- temp_dir:

  Parent directory for temporary files (`--temp-dir`); `NULL` uses the
  system temporary directory.

- debug:

  If \> 0, process only this many units (`--debug`).

- verbose:

  Verbosity (`--verbose`).

- bin:

  Path to `punkst`; see
  [`punkst_setup()`](https://vjcitn.github.io/punkstR/reference/punkst_setup.md).

- overwrite:

  Re-run even if the manifest shows the stage is up to date.

## Value

A `punkstModel` stage object. `files` holds `model` (features x topics)
and `state` always, plus `results` (per-unit topic proportions) and
`pseudobulk` when the transform ran, and `unit_stats` when `residuals`
is on.

## Details

One deliberate difference: punkst does not run the transform by default,
but the results file is what most users need, so `transform = TRUE`
here. Note also that punkst does not sort topics unless
`sort_topics = TRUE`.

## Examples

``` r
# Requires the 'punkst' binary (see check_punkst_setup()); skipped otherwise.
hex <- punkstHex(workdir = tempdir(),
    files = list(data = tempfile(), meta = tempfile()), params = list())
tryCatch(
    punkst_topic_model(hex, n_topics = 2L),
    error = function(e) message("punkst not available: ", conditionMessage(e)))
#> [punkstR] topic_model_file1a70416d9556.k2: running
#> punkst not available: punkst topic-model failed with exit status 134. Last log lines (/tmp/RtmpttWHGi/topic_model_file1a70416d9556.k2.log):
#>     --topk-only [-1], --in-dge-dir, --in-barcodes, --in-features, --in-matrix,
#>     --dataset-id, --features, --min-count-per-feature [1], --default-weight [-1],
#>     --icol-weight [-1], --include-feature-regex, --exclude-feature-regex,
#>     --seed [-1], --threads [0], --n-epochs [1], --minibatch-size [512],
#>     --min-count-train [20], --modal [0], --debug [0], --verbose [0], --kappa [0.7],
#>     --tau0 [10], --eta [-1], --max-iter [100], --mean-change-tol [0.001],
#>     --n-topics [2], --alpha [-1], --reproducible-init [false], --model-prior,
#>     --prior-scale [-1], --prior-scale-rel [-1], --projection-only [false],
#>     --fit-background [false], --background-prior, --background-init-scale [0.5],
#>     --fix-background [false], --bg-fraction-prior-a0 [2],
#>     --bg-fraction-prior-b0 [8], --warm-start-epochs [0.5]
#> 
#> terminate called after throwing an instance of 'std::runtime_error'
#>   what():  Error opening metadata file /tmp/RtmpttWHGi/file1a70194345ba
#> Aborted (core dumped)
```
