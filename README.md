# SII: Speech Intelligibility Index, Loudness Modeling, and Open-NL Prescriptive Testbed

[![R-CMD-check](https://github.com/r-gregmisc/SII/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/r-gregmisc/SII/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/SII)](https://cran.r-project.org/package=SII)
![License](https://img.shields.io/badge/License-GPL--3-blue.svg)

The **`SII`** R package provides an open-source, mathematically inspectable implementation of the **ANSI S3.5-1997 Speech Intelligibility Index (SII)**, an integrated high-performance **C++ Moore & Glasberg (2004) impaired physiological loudness model**, and **Open-NL**, a modular computational testbed for hearing aid prescriptive optimization.

---

## 📖 Manuscript & Scientific Documentation

This repository hosts both the R package codebase and the companion manuscript submitted to the *Journal of the Acoustical Society of America* (JASA):

* **Main Manuscript:** [`OpenNL_manuscript.pdf`](OpenNL_manuscript.pdf) (Markdown source: [`OpenNL_manuscript.md`](OpenNL_manuscript.md))  
  *Title:* *"Open-NL: An Open-Source Intelligibility-Maximizing Prescriptive Testbed with Embedded Physiological Loudness Constraints"*
* **Supplementary Material:** [`OpenNL_Supplementary_Material.pdf`](OpenNL_Supplementary_Material.pdf) (Markdown source: [`OpenNL_Supplementary_Material.md`](OpenNL_Supplementary_Material.md))  
  *Contains full step-by-step mathematical derivations, filterbank equations, and heuristic formulas for Sections II.C through II.N.*
* **Peer-Review Reproducibility Suite:** [`reproducibility_scripts/`](reproducibility_scripts/)  
  *Standalone scripts to reproduce all tables, figures, and numerical validations reported in the paper.*

---

## 🎯 Statement of Need & Core Thesis

Clinical hearing aid fitting is dominated by rationales such as NAL-NL2 and DSL m[i/o] v5.0. While their optimization philosophies are published in broad strokes, their compiled fitting software is distributed as closed-source binary dynamic-link libraries (DLLs). Consequently, hearing scientists and audiology researchers cannot "pop the hood" to test, isolate, or ablate individual prescriptive heuristics without reverse-engineering an entire proprietary pipeline.

**The `SII` package and Open-NL solve this dilemma by:**
1. **Coupling Speech Intelligibility with Physiological Loudness:** Pairing ANSI S3.5 calculation with a compiled C++ implementation of the canonical Moore & Glasberg (2004) specific-loudness model via `Rcpp` (~13 ms per evaluation).
2. **Multi-Level Optimization:** Using Nelder-Mead simplex search to simultaneously maximize Speech Intelligibility (Effective SII) across soft (50 dB SPL), conversational (65 dB SPL), and loud (80 dB SPL) speech inputs.
3. **Emergent WDRC:** Allowing wide dynamic range compression ratios to emerge naturally from physiological loudness ceilings, while auditing outputs against clinical distortion boundaries (CR $\le$ 3.0:1).
4. **Transparent Ablation:** Providing modular switches for severe-loss boosters, dead-region roll-offs, slope-dependent low-frequency penalties (SD-LFP), and air-bone gap (ABG) mechanical restoration.

---

## 📦 Installation

### From CRAN (v1.2.4 incoming)
Once the incoming review clears:
```R
install.packages("SII")
```

### From GitHub (Development Version)
To install the latest release directly from GitHub:
```R
if (!requireNamespace("remotes", quietly = TRUE)) {
  install.packages("remotes")
}
remotes::install_github("r-gregmisc/SII")
```
*(Note: Because the physiological loudness engine is written in compiled C++, installing from GitHub requires a C++ compiler such as Rtools on Windows or Xcode Command Line Tools on macOS).*

---

## 🚀 Quickstart Usage

### 1. Standard ANSI S3.5 SII Calculation
```R
library(SII)

# Compute SII for normal hearing at 65 dB SPL
sii_result <- sii(
  speech = 65,
  noise = 30,
  threshold = rep(0, 6),
  freq = c(250, 500, 1000, 2000, 4000, 8000)
)
print(sii_result$sii)
```

### 2. Generating Open-NL Prescriptive Targets
```R
library(SII)

# Prescribe WDRC targets for a moderate-to-severe sloping hearing loss
audiogram <- c(20, 25, 40, 60, 75, 80)
freqs <- c(250, 500, 1000, 2000, 4000, 8000)

target <- open_nl(
  speech = 65,
  threshold = audiogram,
  freq = freqs
)

# Print prescription and extract target gains
print(target)
target$gain  # Insertion gain targets (dB)
target$mpo   # Maximum Power Output ceiling (dB SPL)

# Evaluate aided Effective SII and monaural loudness
aided <- sii(target, speech = 65)
cat(sprintf("Effective SII: %.3f\n", aided$sii))

loudness <- calculate_loudness(target)
cat(sprintf("Monaural Loudness: %.2f sones\n", loudness$total))
```

### 3. Exploring Heuristic Ablations
```R
# Test the aggressive severe-loss booster (from paper's stress-test analysis)
aggressive_target <- open_nl(
  speech = 65,
  threshold = audiogram,
  freq = freqs,
  enable_severe_booster = TRUE,
  booster_onset = 60,
  disable_sdlfp = TRUE  # Disable slope-dependent low-frequency penalty
)
```

---

## 🔬 Reproducing Manuscript Results

All tables, figures, and computational benchmarks from the JASA manuscript can be replicated using the scripts located in [`reproducibility_scripts/`](reproducibility_scripts/):

```bash
# 1. Regenerate Figure 1 (ANSI vs. Effective SII)
Rscript reproducibility_scripts/plot_fig1_sii_grouped.R

# 2. Regenerate Figure 2 (Multi-Level Insertion Gain Targets across A1-A7)
Rscript reproducibility_scripts/plot_final_gains.R

# 3. Print Table III (Emergent Compression Ratios)
Rscript reproducibility_scripts/generate_table3_cr.R

# 4. Print Tables VI and VII (Loudness, SII, and Insertion Gains)
Rscript reproducibility_scripts/generate_tables.R

# 5. Run the 256-parameter sensitivity sweep & Figure 4
Rscript reproducibility_scripts/generate_sensitivity_fig.R

# 6. Run SD-LFP ablation demonstration
Rscript reproducibility_scripts/run_sdlfp_ablation.R
```

Detailed documentation and parameter mappings are available in [`reproducibility_scripts/README.md`](reproducibility_scripts/README.md).

---

## 📂 Repository Structure

```text
├── DESCRIPTION               # R package metadata (v1.2.4)
├── NAMESPACE                 # Exported package functions and C++ imports
├── R/                        # Core R package source code
│   ├── benchmark_targets.R   # Canonical A1–A7 profiles & NAL-NL2 targets
│   ├── moore_glasberg.R      # R wrapper for specific loudness engine
│   ├── nalr.R                # NAL-R anchors & SSPL90/MPO calculation
│   ├── open_nl.R             # Nelder-Mead optimization testbed
│   ├── plot.SII.R            # Diagnostic S3 plotting methods
│   └── sii.R                 # ANSI S3.5-1997 calculation engine
├── src/                      # High-performance C++ implementation
│   ├── bramslow2004.cpp      # Moore & Glasberg (2004) loudness model
│   └── RcppExports.cpp       # Rcpp glue code
├── OpenNL_manuscript.md      # JASA main manuscript (Markdown)
├── OpenNL_manuscript.pdf     # JASA main manuscript (Compiled PDF)
├── OpenNL_Supplementary_Material.md  # Step-by-step math derivations
├── OpenNL_Supplementary_Material.pdf # Supplementary Material (PDF)
├── manuscript_figures/       # Publication-quality figures (300 DPI)
├── reproducibility_scripts/  # Independent replication scripts
└── tests/                    # testthat regression and validation tests
```

---

## ⚠️ Non-Clinical Research Disclaimer

**The `SII` package and `Open-NL` are explicitly designed and flagged as non-clinical computational tools for theoretical modeling and simulation only.** 

`Open-NL` targets have not undergone clinical trials or human listener validation, and the software is strictly contraindicated for direct clinical hearing aid fitting. Applying raw uncalibrated targets to human subjects carries an inherent risk of loudness discomfort or acoustic over-amplification. Any deployment on human subjects mandates Institutional Review Board (IRB) approval, real-ear verification, and strict loudness discomfort testing.

---

## 👥 Authors & Maintainership

* **Original ANSI Engine:** Gregory R. Warnes
* **Open-NL Testbed, C++ Loudness Engine, & Package Maintainer:** Mark Shaver (`mark.shaver@posteo.net`)
* **Original Funding:** Center for Bioscience Education and Technology (CBET) at the Rochester Institute of Technology (RIT).

## 📄 License

This software is released under the **GNU General Public License, Version 3 (GPL-3)**.
