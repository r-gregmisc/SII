# Open-NL Reproducibility Scripts & Peer-Review Toolkit

This directory contains the complete suite of standalone R and Octave/MATLAB scripts required to reproduce all figures, tables, and computational validation benchmarks reported in the manuscript:

**"Open-NL: An Open-Source Intelligibility-Maximizing Prescriptive Testbed with Embedded Physiological Loudness Constraints"**

---

## 1. Directory & File Manifest

| Manuscript Item | Description | Script to Run | Output Artifact |
|:---|:---|:---|:---|
| **Figure 1** | ANSI SII vs Effective SII (50, 65, 80 dB SPL) | `Rscript reproducibility_scripts/plot_fig1_sii_grouped.R` | `manuscript_figures/OpenNL_vs_NALNL2_SII_Grouped.png` |
| **Figure 2** | Insertion Gain Targets across A1–A7 (50, 65, 80 dB SPL) | `Rscript reproducibility_scripts/plot_final_gains.R` | `manuscript_figures/OpenNL_vs_NALNL2_Gain_Final.png` |
| **Figure 4** | Monte Carlo Stability & Hyperparameter Sensitivity Sweep | `Rscript reproducibility_scripts/generate_sensitivity_fig.R` | `manuscript_figures/Figure4_Sensitivity.png` |
| **Table III** | Effective Compression Ratios (Gain50 / Gain80) | `Rscript reproducibility_scripts/generate_table3_cr.R` | Markdown table to console |
| **Table IV** | 256-Parameter Sensitivity Sweep Variance | `Rscript reproducibility_scripts/generate_sensitivity_fig.R` | `manuscript_figures/sensitivity_progress.csv` |
| **Table VI** | Monaural Loudness (Sones) & SII across A1–A7 | `Rscript reproducibility_scripts/generate_tables.R` | Markdown table to console |
| **Table VII** | Insertion Gain Targets (dB) across A1–A7 at 65 dB SPL | `Rscript reproducibility_scripts/generate_tables.R` | Markdown table to console |
| **Section II.P** | Slope-Dependent Low-Frequency Penalty (SD-LFP) Ablation | `Rscript reproducibility_scripts/run_sdlfp_ablation.R` | Ablation delta report to console |
| **Section II.Q** | Multi-level (50/65/80 dB) Loudness & Gain Matrix | `Rscript reproducibility_scripts/gen_multi_level_tables.R` | Markdown table to console |
| **Section III** | C++ Loudness Engine vs. Canonical AMT Validation | `Rscript reproducibility_scripts/validate_amt_loudness.R` | `evaluate_amt_speech.m` (Octave) |

---

## 2. Requirements & Setup

All scripts rely on the compiled `SII` package and standard data analysis packages:
* **R Packages:** `SII` (v1.2.4), `ggplot2`, `dplyr`, `tidyr`, `stringr`, `reshape2`, `parallel`
* **C++ Compiler:** GCC/Clang with C++17 support (automatically invoked via `Rcpp`)
* **Optional (AMT Validation):** GNU Octave or MATLAB with the [Auditory Modeling Toolbox (AMT)](http://amtoolbox.org/) installed (`bramslow2004` model)

To ensure the local development version of `SII` is active:
```R
devtools::load_all(".")
```

---

## 3. Quickstart Replication Commands

To regenerate all primary figures and print all core tables:

```bash
# 1. Regenerate Figures 1 and 2
Rscript reproducibility_scripts/plot_fig1_sii_grouped.R
Rscript reproducibility_scripts/plot_final_gains.R

# 2. Print Tables III, VI, and VII to console
Rscript reproducibility_scripts/generate_table3_cr.R
Rscript reproducibility_scripts/generate_tables.R

# 3. Run SD-LFP heuristic ablation
Rscript reproducibility_scripts/run_sdlfp_ablation.R

# 4. (Optional) Run full 768-permutation Monte Carlo analysis & Figure 4
Rscript reproducibility_scripts/generate_sensitivity_fig.R
```
