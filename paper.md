---
title: 'SII: An R package for Speech Intelligibility Index calculation and loudness modeling'
tags:
  - R
  - audiology
  - psychoacoustics
  - speech intelligibility
  - hearing aids
  - ANSI S3.5
authors:
  - name: Mark Shaver
    orcid: 0000-0000-0000-0000
    affiliation: 1
affiliations:
  - name: Wichita State University, Department of Communication Sciences and Disorders
    index: 1
bibliography: paper.bib
---

# Summary

The `SII` package for R provides a vectorized computational engine for the ANSI S3.5-1997 (R2012) Speech Intelligibility Index (SII) [@ansi1997], coupled with an integrated non-linear loudness model. Unlike proprietary standards distributed as closed-source binaries, this package offers a fully inspectable, object-oriented S3 API. 

The SII engine implements the standard's calculations and fully supports the standard's alternative band structures (critical, 1/3-octave, octave) and arbitrary noise spectrum inputs. It extends this base functionality by providing an implementation of the Chen et al. [@chen2011] non-linear loudness model. Combining SII and Moore–Glasberg style excitation models is a standard analytical pairing used to evaluate prescriptive methods [@johnson2011]. Notably, Rhebergen and colleagues [@rhebergen2010] built an SII variant using similar excitation modeling to estimate internal levels, reducing prediction variability across impaired listeners. This package allows researchers to estimate loudness in sones simultaneously with speech intelligibility for comparative and relative research work. 

Additionally, an experimental open-source prescriptive algorithm, Open-NL, is included for exploring Wide Dynamic Range Compression (WDRC) heuristics. An interactive, serverless WebAssembly (Wasm) application[^1] facilitates translational clinical research without patient data leaving the browser. 

[^1]: Available at [euphonic-euphemism.github.io/SII](https://euphonic-euphemism.github.io/SII/)

# Statement of Need

Historically, hearing science and audiology researchers have lacked access to a maintained, tested, native-R implementation combining SII with an impaired-loudness model in a single S3 pipeline. While implementations of the SII exist in Python (e.g., the `acoustics` library, `pysii`, or `hearinglosssimulator`) or closed MATLAB scripts (e.g., the Loudness Toolbox), these alternatives often lack robust impaired-loudness integration, and none integrate natively with the R ecosystem (unlike existing R audio tools like `tuneR` or `seewave` which focus on acoustic analysis rather than SII metrics). Furthermore, while the clinical standard for hearing aid prescriptive modeling is dominated by rationales such as NAL-NL2 [@keidser2011] and DSL v5.0 [@scollie2005], those are separate from the core SII metrics and are distributed as compiled, closed-source dynamic-link libraries (DLLs). 

The `SII` package addresses this gap by exposing a transparent computational engine for ANSI S3.5 calculations, replacing the archived and limited predecessor versions of the package. This enables independent laboratories to natively investigate how varying frequency bands, input levels, and thresholds influence speech intelligibility without relying on proprietary black boxes.

# Implementation and Validation

## The ANSI S3.5-1997 Computational Engine

The core `sii()` function leverages vectorized matrix operations for high-throughput calculation of large datasets. The `SII` package explicitly implements the self-masking spread function as defined by standard ANSI models [@pavlovic1987]. The engine is verified against the gold-standard ground truth arrays provided in the ANSI S3.5-1997 (R2012) standard [@ansi1997]: matches are achieved for both the Annex B (Normal Hearing, computed SII = 0.504) and Annex C (Hearing Impaired, computed SII = 0.443) worked examples, with residuals of 0.000. Users should note the known limitations of the SII itself, particularly the band-independence assumption and its limited accuracy with nonstationary maskers, to avoid over-reading the index.

## The Loudness Model

The package includes a non-linear loudness model, `calculate_loudness()`, implementing the model of Chen et al. [@chen2011]. This model builds a nonlinear filterbank in which each filter is the sum of a broad passive and a sharp active roex filter, calculating loudness directly as the area under the excitation pattern (with no specific-loudness transformation required). While the algorithm reproduces the expected qualitative behavior of the source model (see Table 1), it currently lacks direct validation against human listener behavioral data within this package.

For impaired ears where only the pure-tone audiogram is provided as input, the package applies a documented modeling assumption for the key free parameter: outer hair cell (OHC) loss. By default, OHC loss is apportioned as 65% of the sensorineural threshold elevation (capped at 57.6 dB, representing the maximum active-filter gain in the underlying model), with the remainder assigned to inner hair cell (IHC) loss. Because behavioral data suggests OHC dysfunction averages roughly 60–70% with large individual variability, this proportion is exposed as a user-settable parameter (`ohc_proportion` in `calculate_loudness()`). Users should note that threshold-based parameterizations inherently fail to capture individual variation in high-level loudness perception for impaired ears, as audiograms cannot recover the exact OHC/IHC split.

Table 1 demonstrates verification checks for the loudness engine against physiological anchors and published model behavior.

**Table 1. Verification checks for the loudness engine.**

| Test Condition | Expected Behavior | Computed Result |
| :--- | :--- | :--- |
| **ISO 226 Anchor (Normal)** | 1.0 ± 0.05 Sones (40 phons) | 1.01 Sones |
| **Loudness Growth (Normal)** | Matches Chen Fig. 5 (1 kHz sones vs level) | Pass (within 10% deviation) |
| **Excitation Pattern (Normal)** | Matches Chen Fig. 2 (1 kHz at 80 dB SPL) | Pass (Qualitative shape) |
| **Broadband Summation (Normal)**| > 1.0 Sones, < 2.0 Sones | 1.76 Sones |
| **Loudness Divergence (Impaired)**| 70 dB SPL (60 HL) < normal ear | 3.5 Sones (Impaired) vs 8.4 (Normal) |
| **Loudness Recruitment (Impaired)**| 100 dB SPL (60 HL) converges to normal (± 5%) | 65.2 Sones (Impaired) vs 66.8 (Normal, 2.4% dev) |

## Architecture and S3 API

To support reproducible pipelines, the package has been decoupled to utilize an object-oriented S3 class architecture. Gain prescriptions generated by helper functions (e.g., `open_nl()`) return `prescription_target` objects equipped with standard `print()`, `summary()`, and `plot()` methods. 

The Open-NL module is strictly an experimental heuristic for research purposes. Open-NL implements a rule-based WDRC heuristic calculating insertion gain based on half-gain rules for mild losses, and automatically escalates compression ratios for severe losses to map the residual dynamic range. However, prescriptive targets derive their validity from listener outcomes and real-ear verification, and deviation from validated targets measurably degrades speech recognition. Therefore, Open-NL is not intended for clinical hearing aid fitting.

```r
library(SII)

# Generate a WDRC target
target <- open_nl(speech = 65, threshold = c(20, 25, 40, 60, 75, 80), 
                  freq = c(250, 500, 1000, 2000, 4000, 8000))
plot(target)

# Evaluate SII using the S3 object directly
aided_sii <- sii(target, speech = 65)
```

The codebase enforces continuous integration through GitHub Actions and maintains a comprehensive `testthat` suite. The package source and releases are archived via Zenodo (DOI: pending) under the GPL-3.0 license.

# Acknowledgments

The core ANSI engine of the `SII` package derives from an earlier archived CRAN package originally developed by Gregory R. Warnes, and is released here with full GPL-3.0 compatibility and documented agreement to revive the namespace. Maintainership formally transferred to the current author starting with version 1.1.0. All subsequent loudness modeling (`calculate_loudness`), the S3 API refactoring, the WebAssembly implementation, and the `Open-NL` prescriptive logic were independently developed by the current author. 

### Author Contributions

The submitting author (Mark Shaver) was responsible for all scientific design decisions, algorithmic specifications, and validations, utilizing an LLM assistant strictly for syntax translation and boilerplate generation.

# References
