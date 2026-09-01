# Reproducibility Scripts

This directory contains the core R scripts used to generate the tables and figures found in the manuscript.

## Main Scripts

- `gen_multi_level_tables.R`: This is the primary script used to generate the final multi-level benchmarking table for profiles A1 through A7 across 50, 65, and 80 dB SPL input levels. It evaluates targets using both NAL-NL2 and Open-NL (which utilizes a bounded Nelder-Mead optimization against a U-shaped clinical loudness tolerance envelope).
- `generate_tables.R`: Generates the baseline performance tables.
- `generate_remaining_tables.R`: Generates supplementary table metrics.

## Requirements

To run these scripts, ensure the `SII` package is compiled and loaded correctly. The scripts rely on `devtools::load_all()` to dynamically load the package from the root directory during development.

## Notes for Peer Reviewers

The Open-NL algorithm dynamically evaluates physiological limits at runtime using a C++ integration of the Moore & Glasberg (2004) specific loudness model. Optimization targets are explicitly limited to standard octave frequencies (250, 500, 1000, 2000, 4000, 8000 Hz) to ensure outputs are pragmatically verifiable on standard clinical REM equipment, while the internal physiological evaluation interpolates these limits onto a high-resolution grid.
