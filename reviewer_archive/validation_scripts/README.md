# Reviewer Validation Scripts

This directory contains the necessary R scripts to validate the performance of the Open-NL prescription algorithm as described in the manuscript. The scripts compare Open-NL outputs to NAL-NL2 and normal hearing profiles.

## Core Scripts

* `generate_multi_level_tables.R`: This is the primary script used to generate the benchmark tables. It calculates the Speech Intelligibility Index (SII) and Loudness (in Sones) for the 7 standard audiometric profiles (A1-A7) originally defined by Johnson & Dillon (2011). It performs head-to-head comparisons of NAL-NL2 versus Open-NL at three input levels: Soft (50 dB SPL), Average (65 dB SPL), and Loud (80 dB SPL).

## Dependencies

These validation scripts rely heavily on the internal C++ bindings and datasets embedded within the `SII` R package.
1. `devtools::load_all(".")` is used to load the package environment. This must be executed from the root directory of the repository.
2. The `jd2011_targets` dataset contains the standard pure-tone thresholds and expected NAL-NL2 outputs used for benchmarking.
3. Loudness calculations utilize the `calculate_loudness_cpp` function, which is a C++ implementation of the Moore & Glasberg (2004) loudness model for hearing impaired listeners (Bramslow, 2004).

## Running the Scripts

To execute the main benchmark generation, simply source the script from the project root:

```R
# From the R console at the repository root
source("reviewer_archive/validation_scripts/generate_multi_level_tables.R")
```

The script will stream a Markdown-formatted table to the console outlining the Profile, Input Level, Method, SII, and Sones.
