# Loudness Calculation Discrepancy Debugging

## Issue Overview
We investigated a discrepancy where the `open_nl` optimizer successfully constrained the output loudness to ~5.00 sones, but the Shiny UI persistently evaluated the exact same target gain curve as 8.7 sones.

## Investigation and Resolution
1. **Mathematical Alignment**: 
   We refactored `open_nl.R` to strictly evaluate the loudness constraint using the 6-band free-field `calculate_loudness_cpp` path, identical to what is used by `Shiny`, completely avoiding the 21-band interpolated logic that previously caused mismatched target outputs.
2. **Side-by-Side Proof**: 
   We ran a direct memory-level comparison of the arrays being passed to the Bramslow (2004) C++ loudness model. We verified that for the exact same target gain (the final Open-NL result):
   - The unamplified speech array, insertion gain array, air-bone gaps, and OHC/IHC arrays are identical.
   - The `dense_l` extrapolation logic produces a difference of `0`.
   - The C++ module returns exactly `4.993513` sones internally for the optimizer **and** when evaluated natively using the Shiny `sii()` logic.

The 8.7 sones mismatch previously reported in Shiny was an artifact of the Shiny app referencing an older, un-updated version of the `SII` package in memory before our alignment fixes were compiled.

## Conclusion
The optimizer is verified to be functioning exactly as intended and the loudness calculations are completely unified. I have cleaned up the debug logging from the optimizer code so it will run silently and quickly again.
