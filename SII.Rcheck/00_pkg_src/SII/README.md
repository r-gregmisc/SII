# SII: Speech Intelligibility Index and Loudness Calculation in R

[![R-CMD-check](https://github.com/r-gregmisc/SII/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/r-gregmisc/SII/actions/workflows/R-CMD-check.yaml)
![Coverage](https://img.shields.io/badge/Coverage-94%25-brightgreen.svg)

The `SII` package calculates the ANSI S3.5-1997 Speech Intelligibility Index (SII), a standard method for computing the intelligibility of speech from acoustical measurements of speech, noise, and hearing thresholds. 

It also provides an integrated physiological loudness model based on Moore & Glasberg (2004) and Chen et al. (2011), enabling hearing scientists to estimate loudness in sones simultaneously with speech intelligibility.

## Statement of Need

Historically, hearing science and audiology researchers have lacked access to open, fully inspectable implementations of foundational acoustical metrics in R, leading to the archival of earlier, limited toolsets like the original `SII` package. While some implementations exist in other languages (e.g., Python's `acoustics` library which lacks Moore-Glasberg loudness or closed MATLAB scripts), researchers requiring robust SII and impaired physiological loudness modeling within the R ecosystem have had to rely on fragmented or proprietary tools. The clinical standard for hearing aid prescriptive modeling is dominated by rationales such as NAL-NL2 and DSL v5.0, which are distributed as compiled, closed-source dynamic-link libraries (DLLs) to manufacturers. 

The `SII` package addresses this gap by exposing a transparent computational engine for ANSI S3.5 calculations alongside physiological loudness predictions. This promotes reproducibility in audiological research, allowing independent laboratories to natively verify how algorithmic parameter shifts influence speech intelligibility and loudness outcomes without relying on proprietary black boxes.

## Installation

You can install the development version from GitHub:

```r
# install.packages("devtools")
devtools::install_github("r-gregmisc/SII")
```

## Example Usage

### 1. Basic ANSI S3.5 Calculation

```r
library(SII)

# Calculate SII for normal hearing
sii_result <- sii(speech = 65, noise = 30, threshold = rep(0, 6), freq = c(250, 500, 1000, 2000, 4000, 8000))
print(sii_result$sii)
```

### 2. Generating a WDRC Prescription Target

The package includes `Open-NL`, an experimental open-source prescriptive algorithm for exploring Wide Dynamic Range Compression (WDRC) heuristics. (Note: this is strictly an experimental heuristic for research purposes; it lacks human listener validation data and is not intended for clinical fitting).

```r
# Generate a WDRC target for a moderate hearing loss
target <- open_nl(speech = 65, 
                  threshold = c(20, 25, 40, 60, 75, 80), 
                  freq = c(250, 500, 1000, 2000, 4000, 8000))

# The target object supports standard S3 methods
print(target)
plot(target)

# Evaluate the SII of the proposed target using the object API
aided_sii <- sii(target, speech = 65)
print(aided_sii$sii)
```



## API Documentation

Core functions:
- `sii()`: Computes the ANSI S3.5-1997 Speech Intelligibility Index.
- `calculate_loudness()`: Estimates physiological loudness in sones using the Moore & Glasberg (2004) impaired loudness model.
- `open_nl()`: Generates dynamic WDRC prescription targets.

Detailed parameter definitions and methodologies can be found in the package R documentation (e.g., `?sii`, `?open_nl`).

## Community Guidelines

We welcome community contributions to the `SII` package!

- **Issue Reporting**: If you encounter a bug, have a feature request, or need support, please open an issue on the [GitHub Issues](https://github.com/r-gregmisc/SII/issues) page. Please include reproducible code examples if reporting a bug.
- **Contributing**: To contribute code, please fork the repository, create a feature branch, and submit a Pull Request. Please ensure that all `testthat` unit tests pass and that your code adheres to standard R style guidelines.
- **Support**: For general questions, feel free to start a discussion on the GitHub repository or contact the maintainer directly.

## Authors and Acknowledgment

The core ANSI engine of the `SII` package was originally developed by Gregory R. Warnes. Maintainership formally transferred to Mark Shaver starting with version 1.1.0. All subsequent physiological loudness modeling, the S3 API refactoring, the WebAssembly implementation, and the `Open-NL` prescriptive logic were independently developed by Mark Shaver.

Development of the original package was funded by the Center for Bioscience Education and Technology (CBET) of the Rochester Institute of Technology (RIT).

## Methodology & Architectural Notes

### 1. Open-NL Optimization Architecture (R vs. MATLAB)
While foundational psychoacoustic models (e.g., AMToolbox) frequently originate as MATLAB reference scripts, the **Open-NL** prescriptive framework was intentionally engineered natively in R. This architectural decision guarantees that the framework remains completely free and open-source (FOSS), preventing the "black box" siloing that occurs with proprietary algorithms (NAL-NL2, DSL) or algorithms dependent on expensive commercial MATLAB licenses.

Furthermore, R's robust statistical and optimization ecosystem is fundamentally superior for this class of problem. Open-NL uses a highly efficient Nelder-Mead optimization loop to maximize the ANSI S3.5 Effective SII subject to dynamic loudness penalties. To overcome R's interpretive overhead during intensive looped evaluations, the Moore & Glasberg (2004) loudness model was natively ported to compiled C++ and directly integrated via `Rcpp`. This enables the optimization loop to evaluate tens of thousands of candidate gain curves in seconds rather than minutes, unlocking dynamic, real-time prescription modeling previously unattainable in standard scripting environments.

### 2. Inner and Outer Hair Cell (IHC/OHC) Loss Differentiation
Consistent with physiological models of sensorineural hearing loss, the C++ loudness engine explicitly isolates outer hair cell (OHC) damage from inner hair cell (IHC) damage. By default, hearing loss (dB HL) up to 65 dB is attributed to OHC dysfunction, which drives the filter widening (reduced frequency selectivity) simulated in the cochlear model. Loss exceeding 65 dB is attributed to IHC dysfunction, which attenuates the overall signal gain but does not cause further filter widening. This differentiation prevents the artificial "runaway" filter widening that can corrupt loudness estimates in severe-to-profound hearing losses.

### 3. Spectral Density Conservation
The ANSI S3.5 calculation relies on 1/3-octave band energies, while the physiological loudness model operates on a dense 1-Hz spectral density grid prior to excitation summation. The package ensures mathematical fidelity by natively passing the Equivalent Speech Spectrum Levels (spectrum densities in dB/Hz) directly through the R pipeline, preventing artificial energy inflation associated with double-conversion algorithms.
