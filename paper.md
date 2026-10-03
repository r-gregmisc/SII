---
title: 'SII: An R package for Speech Intelligibility Index calculation and loudness modeling'
tags:
  - R
  - audiology
  - psychoacoustics
  - hearing loss
  - speech intelligibility
  - ANSI S3.5
date: "13 August 2026"
authors:
  - name: Mark Shaver
    orcid: "0000-0000-0000-0000"
    affiliation: 1
affiliations:
  - name: Wichita State University, Department of Communication Sciences and Disorders, Wichita, USA
    index: 1
bibliography: paper.bib
---

# Summary

The `SII` package for R provides a vectorized computational engine for the ANSI S3.5-1997 (R2024) Speech Intelligibility Index (SII) [@ansi1997], coupled with an integrated non-linear loudness model. Unlike proprietary standards distributed as closed-source binaries, this package offers a fully inspectable, S3 class-based API. 

The SII engine implements the standard's calculations and fully supports the standard's alternative band structures (critical, 1/3-octave, octave) and arbitrary noise spectrum inputs. It extends this base functionality by providing an implementation of the non-linear loudness model of Chen et al. [@chen2011]. Combining SII and Moore–Glasberg style excitation models is a standard analytical pairing used to evaluate prescriptive methods [@johnson2011]. Notably, Rhebergen and colleagues [@rhebergen2010] built an SII variant using similar excitation modeling to estimate internal levels, reducing prediction variability across impaired listeners. This package allows researchers to estimate loudness in sones simultaneously with speech intelligibility for comparative and relative research work. 

Additionally, an experimental open-source prescriptive algorithm, Open-NL, is included for exploring Wide Dynamic Range Compression (WDRC) heuristics. An interactive, serverless WebAssembly application[^1] facilitates translational clinical research without patient data leaving the browser. 

[^1]: Available at [euphonic-euphemism.github.io/Open-NL](https://euphonic-euphemism.github.io/Open-NL/)

# Statement of Need

Historically, hearing scientists, audiology researchers, and psychoacousticians have lacked access to a maintained, tested, native-R implementation combining SII with an impaired-loudness model in a single S3 pipeline. While implementations of the SII exist in Python (e.g., the `acoustics` library, `pysii`, or `hearinglosssimulator`) or closed MATLAB scripts (e.g., the Loudness Toolbox), these alternatives often lack robust impaired-loudness integration, and none integrate natively with the R ecosystem (unlike existing R audio tools like `tuneR` or `seewave` which focus on acoustic analysis rather than SII metrics). Furthermore, while the clinical standard for hearing aid prescriptive modeling is dominated by rationales such as NAL-NL2 [@keidser2011] and DSL v5.0 [@scollie2005], those are separate from the core SII metrics and are distributed as compiled, closed-source dynamic-link libraries (DLLs). 

The `SII` package addresses this gap by exposing a transparent computational engine for ANSI S3.5 calculations, replacing the archived CRAN `sii` version 1.0. This enables independent laboratories to natively investigate how varying frequency bands, input levels, and thresholds influence speech intelligibility without relying on proprietary black boxes. This package is intended to enable rapid prototyping of novel hearing aid compression rationales and large-scale retrospective analyses of speech intelligibility across diverse clinical datasets.

# Implementation and Validation

## The ANSI S3.5-1997 Computational Engine

The core `sii()` function leverages vectorized matrix operations for high-throughput calculation of large datasets. The `SII` package explicitly implements the self-masking spread function as defined by standard ANSI models [@pavlovic1987]. The engine is verified against the gold-standard ground truth arrays provided in the ANSI S3.5-1997 (R2024) standard [@ansi1997]: matches are achieved for both the Annex B (Normal Hearing, computed SII = 0.504) and Annex C (Hearing Impaired, computed SII = 0.443) worked examples, with maximum absolute residual < 1e-4. Users should note the known limitations of the SII itself, particularly the band-independence assumption and its limited accuracy with nonstationary maskers, to avoid over-reading the index.

## The Loudness Model

The package includes a hybrid non-linear loudness model, `calculate_loudness()`. It leverages the mathematical approximation of Chen et al. [@chen2011] strictly to map the acoustic spectrum into cochlear excitation energy, and then applies the rigorous compressive specific loudness integrals of Moore & Glasberg (2004) [@moore2004] to accurately predict loudness recruitment in impaired ears. 

For impaired ears where only the pure-tone audiogram is provided as input, the package apportions outer hair cell (OHC) loss as 65% of the sensorineural threshold elevation, with the remainder assigned to inner hair cell (IHC) loss. The compressive exponent dynamically approaches 1.0 (linear) proportional to this OHC loss. Because behavioral data suggests large individual variability, this proportion is exposed as a user-settable parameter (`ohc_proportion`). 

To assure methodological rigor, the R engine was subjected to an independent computational validation. An independent, closed-form reference implementation of the Moore & Glasberg (2004) integrals was authored in MATLAB/Octave, utilizing the Auditory Modeling Toolbox's validated cochlear excitation stages (`chen2011`). The predicted monaural loudness (in sones) for a 65 dB SPL speech spectrum fitted with Open-NL targets was computed across seven standard audiometric profiles. The results demonstrated perfect numerical agreement between the two environments, yielding a Root Mean Square Error (RMSE) of 0.0000 sones and a maximum relative deviation of 0.00%.

## Architecture and S3 API

To support reproducible pipelines, the package has been decoupled to utilize an S3 class-based API. Gain prescriptions generated by helper functions (e.g., `open_nl()`) return `prescription_target` objects equipped with standard `print()`, `summary()`, and `plot()` methods.

The Open-NL module is strictly an experimental heuristic for research purposes. Open-NL initially seeds a rule-based WDRC heuristic (using half-gain rules for thresholds < 60 dB HL and dynamic compression ratios for severe losses) and then refines the targets using a Nelder-Mead optimization loop. This optimizer uses natural cubic splines and Tikhonov regularization to maximize the Speech Intelligibility Index while enforcing objective loudness constraints. However, prescriptive targets derive their validity from listener outcomes and real-ear verification, and deviation from validated targets measurably degrades speech recognition. Therefore, Open-NL is not intended for clinical hearing aid fitting, and a prominent non-clinical-use notice is displayed in the WebAssembly application UI.

```r
library(SII)

# Generate a WDRC target
target <- open_nl(speech = 65, threshold = c(20, 25, 40, 60, 75, 80), 
                  freq = c(250, 500, 1000, 2000, 4000, 8000))
plot(target)

# Evaluate SII using the S3 object directly
aided_sii <- sii(target, speech = 65)
```

The codebase enforces continuous integration through GitHub Actions and maintains a comprehensive `testthat` suite. The package source is distributed under the GPL-3.0 license.



## Availability and Installation

The `SII` package source code, releases, and issue tracker are hosted on GitHub. It can be installed directly via `remotes::install_github('euphonic-euphemism/SII')`. To reclaim the archived namespace, a base version of the package has been submitted to CRAN and is currently under manual review; the full feature set described here will be submitted as an update pending that initial acceptance. A persistent archive of the source code is maintained on Zenodo (DOI: 10.5281/zenodo.21798964). Furthermore, the WebAssembly interactive application can be accessed directly at [euphonic-euphemism.github.io/Open-NL](https://euphonic-euphemism.github.io/Open-NL/).

# Acknowledgments

The core ANSI engine of the `SII` package derives from an earlier archived CRAN package originally developed by Gregory R. Warnes, and is released here with full GPL-3.0 compatibility and documented agreement to revive the namespace (archived in the repository's `NOTICE.md` file). Maintainership formally transferred to the current author starting with version 1.1.0. All subsequent loudness modeling (`calculate_loudness`), the S3 API refactoring, the WebAssembly implementation, and the `Open-NL` prescriptive logic were independently developed by the current author. 

# AI Statement

The submitting author (Mark Shaver) utilized an LLM assistant (Antigravity v1.0) strictly for syntax translation and boilerplate generation during development.

# References
