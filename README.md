# SII: Speech Intelligibility Index, Loudness, and the Open-NL Prescription Testbed

[![R-CMD-check](https://github.com/r-gregmisc/SII/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/r-gregmisc/SII/actions/workflows/R-CMD-check.yaml)
[![CRAN status](https://www.r-pkg.org/badges/version/SII)](https://cran.r-project.org/package=SII)
[![License: GPL-3](https://img.shields.io/badge/License-GPL--3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

The `SII` package for R provides:

* **The ANSI S3.5-1997 (R2024) Speech Intelligibility Index**, with the
  standard's band-importance tables, extended by interpolation to audiograms
  measured at non-standard frequencies, and an optional Johnson & Dillon (2011)
  hearing-loss desensitization correction.
* **A loudness model for impaired hearing**: a C++ port of AUDMOD
  (Bramsløw, 2004), verified stage by stage against the `bramslow2004`
  implementation in the Auditory Modeling Toolbox (AMT 1.6.0).
* **Open-NL**, an open, inspectable testbed for hearing aid prescription
  research. Open-NL searches for insertion gains that maximize the SII subject
  to a loudness limit and a simulated maximum power output, so that each
  assumption in a prescription can be changed or removed and its effect
  measured.

Open-NL and the prescription functions are research tools for modeling and
simulation. They have not been clinically validated and are not intended for
fitting hearing aids to patients.

## Installation

From CRAN:

```r
install.packages("SII")
```

Development version from GitHub (needs a C++ compiler: Rtools on Windows,
Xcode Command Line Tools on macOS):

```r
# install.packages("remotes")
remotes::install_github("r-gregmisc/SII")
```

## Examples

### SII for a speech and noise spectrum (ANSI S3.5 Annex C, Example C.1)

```r
library(SII)

res <- sii(
  speech    = c(50, 40, 40, 30, 20, 0),
  noise     = c(70, 65, 45, 25, 1, -15),
  threshold = c(0, 0, 0, 0, 0, 0),
  method    = "octave"
)
res$sii          # 0.504, the value given in the standard
summary(res)     # band-by-band detail
plot(res)
```

### SII with hearing loss desensitization

`desensitization` is either `"none"` (the ANSI SII, the default) or
`"johnson2011_desensitized"` (the Johnson & Dillon, 2011, correction for
reduced benefit from audibility at greater degrees of sensorineural loss).

```r
sii(
  speech    = "raised",
  threshold = c(25, 25, 30, 35, 45, 45, 55, 60),
  freq      = c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000),
  method    = "critical",
  interpolate = TRUE,
  desensitization = "johnson2011_desensitized"
)
```

### Open-NL gain targets

```r
target <- open_nl(
  speech    = 65,                               # input level, dB SPL
  threshold = c(0, 0, 10, 40, 70, 80),          # dB HL
  freq      = c(250, 500, 1000, 2000, 4000, 8000)
)
target          # insertion gain and maximum power output by frequency
target$gain
```

The optimization runs several Nelder-Mead searches and can take up to a minute
per call. Useful arguments include `objective_sii` (which SII to maximize),
`cap_rule` (`"normal"`, the normal-hearing loudness of unaided speech, or the
earlier `"legacy"` rule), `cap_override`, `vent_floor`, and switches for
individual prescription rules (`enable_severe_booster`, `disable_sdlfp`,
`abg_fraction`). See `?open_nl`.

### Aided SII and loudness for an Open-NL target

Pass the target to `sii()` through `prescription`, with the speech spectrum,
thresholds and frequencies stored in the target:

```r
aided <- sii(
  speech       = target$speech,
  threshold    = target$threshold,
  freq         = target$freq,
  prescription = target,
  interpolate  = TRUE,
  desensitization = "johnson2011_desensitized"
)
aided$sii          # aided SII
aided$unaided_sii  # unaided SII, same settings

calculate_loudness(aided)$total   # loudness of the aided speech, sones
```

`calculate_loudness_audmod()` gives direct access to the AUDMOD model; see
`?calculate_loudness_audmod`.

### Testing a prescription rule

Each rule in Open-NL can be switched on or off to measure its effect, for
example:

```r
target_booster <- open_nl(
  speech    = 65,
  threshold = c(0, 0, 10, 40, 70, 80),
  freq      = c(250, 500, 1000, 2000, 4000, 8000),
  enable_severe_booster = TRUE,  # extra gain for severe losses
  booster_onset = 60,            # dB HL at which the booster starts
  disable_sdlfp = TRUE           # turn off the slope-dependent low-frequency penalty
)
target_booster$gain - target$gain
```

## Reproducing published results

Scripts that reproduce the results of studies using this package, and the
checks of the loudness model against AMT, are in
[`reproducibility_scripts/`](https://github.com/r-gregmisc/SII/tree/master/reproducibility_scripts).
Its [README](https://github.com/r-gregmisc/SII/blob/master/reproducibility_scripts/README.md)
maps each table and figure to the script that produces it and says which
package version each script runs on. These scripts are kept in the GitHub
repository only; they are not part of the CRAN package.

## What's new

See [NEWS.md](https://github.com/r-gregmisc/SII/blob/master/NEWS.md). Version
1.3.0 replaced the loudness model with the verified AUDMOD port, made the
normal-hearing loudness cap the Open-NL default, and simplified
desensitization to two options.

## Authors

Gregory R. Warnes (original author of the ANSI S3.5 implementation) and
Mark Shaver (maintainer; loudness model and Open-NL). Development of the
original package was funded by the Center for Bioscience Education and
Technology (CBET) of the Rochester Institute of Technology.

## License

GPL-3.

## References

* ANSI/ASA S3.5-1997 (R2024). *Methods for Calculation of the Speech
  Intelligibility Index.* Acoustical Society of America.
* Bramsløw, L. (2004). An objective estimate of the perceived quality of
  reproduced sound in normal and impaired hearing. *Acta Acustica united with
  Acustica*, 90(6), 1007–1018.
* Johnson, E. E., & Dillon, H. (2011). A comparison of gain for adults from
  generic hearing aid prescriptive methods: Impacts on predicted loudness,
  frequency bandwidth, and speech intelligibility. *Journal of the American
  Academy of Audiology*, 22(7), 441–459.
