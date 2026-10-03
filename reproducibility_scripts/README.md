# Reproducibility scripts

Scripts behind the results reported for Open-NL and the loudness-budget study
submitted to the *Journal of the American Academy of Audiology* (JAAA), plus
the checks used to verify the package's loudness model and SII calculation.

All scripts are run **from the repository root** with the development version
of the package loaded (`devtools::load_all(".")` or an installed build of this
commit). They read and write under `reproducibility_scripts/output/` and
`figures/`.

The scripts fall into four groups:

| Group | Runs on this version (SII 1.3.0)? |
|:---|:---|
| [1. JAAA manuscript](#1-jaaa-manuscript) | Yes |
| [2. Package verification](#2-package-verification) | Yes |
| [3. Earlier JAAA analyses and audits](#3-earlier-jaaa-analyses-and-audits) | No: check out the commit given |
| [4. Earlier Open-NL (JASA) manuscript](#4-earlier-open-nl-jasa-manuscript) | No: check out the commit given |

Groups 3 and 4 are kept as a record of how the current analysis was reached.
They use options that 1.3.0 removed (the `"johnson2011_smoothed"` SII, the
`desensitization_scale` argument, the earlier loudness engine and loudness cap)
and stop with an error if run on this version.

---

## Setup

* R (>= 3.5) with a C++ compiler (the package compiles C++ via Rcpp)
* R packages: `devtools` (or `pkgload`), `dplyr`, `tidyr`, `ggplot2`, `callr`
* For regenerating the AMT reference output only: GNU Octave with the
  [Auditory Modeling Toolbox](https://amtoolbox.org/) 1.6.0

The long runs save every solution to a CSV as they go and **resume** from it
if interrupted: source the script again. If a script stopped with an error,
run `sink()` once at the prompt first.

---

## 1. JAAA manuscript

These reproduce every result in the JAAA manuscript and supplement
(Supplement Table S5). Times are the estimates given in each script's header,
at 20 Nelder-Mead starts per optimization.

| Result | Script (in order) | Output | Time |
|:---|:---|:---|:---|
| Table 1 audiograms; NAL-NL2 gains | `bisgaard_profiles.R` (data, sourced by the scripts below; NAL-NL2 gains exported from NAL-NL2 v2.0, dll v2.15) | – | – |
| Table 2; Figure 1; NAL-NL2 loudness; Tables 4 and 5; Table S2 | `rerun_bisgaard_profiles.R` | `output/bisgaard/` | ~4 h |
| Table 3; resolution limit | `rerun_complete_objective.R` | `output/complete_objective/` | ~10–11 h |
| Figures 1 and 2 | `fig_jaaa.R` (after the two scripts above) | `figures/` (PDF, EPS, TIFF, PNG) | < 1 min |
| Low- vs high-frequency rescoring; unspent budget | `mechanism_check_complete.R` (after `rerun_complete_objective.R`) | console | < 1 min |
| Table S1 (optimizing the ANSI SII) | `rerun_ansi_objective.R` | `output/ansi_objective/` | ~4–5 h |
| Tables S3 and S4; search variability; floor at the normative ceiling | `floor_robustness.R` | `output/floor_robustness/` | ~5–6 h |

`helpers_jaaa.R` holds shared functions (target construction, `report_sii()`)
and is sourced by the scripts above.

Each script states at the top what it reruns and checks its preconditions
before starting (for example, that `open_nl()` optimizes the
`"johnson2011_desensitized"` SII by default).

```r
source("reproducibility_scripts/rerun_bisgaard_profiles.R")
source("reproducibility_scripts/rerun_complete_objective.R")
source("reproducibility_scripts/fig_jaaa.R")
source("reproducibility_scripts/mechanism_check_complete.R")
source("reproducibility_scripts/rerun_ansi_objective.R")
source("reproducibility_scripts/floor_robustness.R")
```

---

## 2. Package verification

| Check | Script | Notes |
|:---|:---|:---|
| AUDMOD loudness port matches AMT 1.6.0 `bramslow2004` at every stage (23 cases) | `audmod_validation/make_cases.R` → `audmod_validation/run_amt_harness.m` (Octave) → `audmod_validation/compare_stages.R` | AMT reference output is in `audmod_validation/out/` and is also used by the package tests (`tests/testthat/test-audmod.R`), so Octave is only needed to regenerate it. Edit the AMT path in the first lines of `run_amt_harness.m`. `amt_harness_log.txt` is the log of the reference run. |
| Standard SII unchanged from the original CRAN release (Warnes) when no new options are used | `regression_vs_cran.R` | Installs the CRAN release into a temporary library; your main library is not touched. |

---

## 3. Earlier JAAA analyses and audits

Development of the JAAA analysis between 15 September and 2 October 2026:
earlier scoring with the smoothed desensitized SII, the audiogram-family and
iso-loudness sweeps, the feasibility maps later removed from the manuscript,
and audits of the loudness cap, the multi-start search, the vent-floor
"dual-run" branch and negative insertion gain. Their outputs are kept in
`output/` (`jaaa_audmod/`, `jaaa_audmod_smoke/`, `isoloudness/`,
`archive_run1_old_scoring/`, `archive_run2_rectified_bramslow/`).

**3a. Run at commit `bc8a08e`** (26 Sep 2026; AUDMOD loudness, smoothed SII
available, `desensitization_scale` available):

```
git checkout bc8a08e
```

`gen_audiogram_family.R`, `gen_budget_decomposition.R`,
`gen_desens_sensitivity.R`, `gen_feasibility_maps.R`,
`gen_iso_loudness_control.R`, `gen_iso_loudness_control_v2.R`,
`rebuild_isoloudness_20.R`, `rebuild_isoloudness_20_naldf_off.R`,
`check_report_sii.R`, `check_outlier_and_noise.R`, `audit_cap_basis.R`,
`audit_nal_ldf.R`, `cap_knots_diagnostic.R`, `cap_rule_comparison.R`,
`baseline_loudness.R`, `fig_budget.R`, `fig_mechanism.R`,
`plot_jaaa_figures.R`, `plot_hf_maps.R`, `plot_sii_maps.R`,
`plot_smoothed_maps.R`, `validate_amt_loudness_45.R`, `run_all.R`,
and everything in `audit/`.

**3b. Ran on uncommitted working states** between `bc8a08e` and `97e2200`
(the smoothed SII still present, with the negative-gain fix to `sii()` and/or
the removal of the vent-floor dual-run branch applied). No commit reproduces
these states exactly, so these scripts will not run unmodified on any commit.
They document the checks that led to those two changes, and their results are
in `output/`.

`anchor_off_check.R`, `budget_check.R`, `masking_check.R`,
`complete_objective_check.R`, `rerun_iso_after_sii_fix.R`,
`rerun_unmatched_tight_budget.R`, `rescore_negative_gain_unclipped.R`,
`rescore_sweep_smoothed.R`, `compare_prefix_postfix_tightbudget.R`,
`verify_dualrun_removal.R`.

The last two compare against `open_nl()` as it was before the dual-run branch
was removed. To recreate that copy:

```
mkdir -p scratch
git show bc8a08e:R/open_nl.R > scratch/open_nl_pre_dualrun_removal.R
```

---

## 4. Earlier Open-NL (JASA) manuscript

Scripts for the earlier Open-NL methods manuscript (`OpenNL_manuscript.*`),
written for the previous loudness engine (a C++ port of `bramslow2004` later
replaced by the validated AUDMOD port), the PTA-based loudness cap (now
`cap_rule = "legacy"`) and the smoothed SII objective. Run at commit
`cee2f06` (13 Sep 2026, the last state before the AUDMOD port):

```
git checkout cee2f06
```

| Manuscript item | Script |
|:---|:---|
| Figure 1: ANSI vs desensitized SII at 50, 65 and 80 dB SPL | `plot_fig1_sii_grouped.R` |
| Insertion gain figure | `plot_final_gains.R` |
| Sensitivity figure and sweep variance | `generate_sensitivity_fig.R`, `generate_lhs_sensitivity.R`, `generate_lhs_sensitivity_safe.R` |
| Effective compression ratios | `generate_table3_cr.R` |
| Loudness, SII and insertion gain tables | `generate_tables.R`, `generate_remaining_tables.R` |
| Multi-level (50/65/80 dB) loudness and gain | `gen_multi_level_tables.R` |
| SD-LFP ablation | `run_sdlfp_ablation.R` |
| Severe-loss booster ablation | `validate_booster_ablation.R` |
| Smoothed vs complete desensitization | `compare_smoothed_complete.R`, `evaluate_smoothed_desensitization_error.R` |
| C++ loudness engine vs AMT (Bland-Altman) | `validate_amt_loudness.R`, `validate_amt_loudness_bland_altman.R`, `validate_amt_loudness_random.R`, `validate_amt_bland_altman_intense.R`, `plot_bland_altman.R`, `plot_bland_altman_intense.R`, `plot_random_bland_altman.R` |

The AMT comparisons in this group also need the Octave `evaluate_amt_*.m`
scripts from that period, which are not included in the repository.
