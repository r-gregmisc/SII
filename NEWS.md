
# SII (development version)

* `open_nl()` gains `objective_sii`, which selects the SII the optimizer maximizes.
  The default is `"johnson2011_complete"`, the Johnson & Dillon (2011)
  desensitization correction; `"none"` optimizes the ANSI S3.5 SII.

* Removed the `"johnson2011_smoothed"` desensitization option (a product-form
  approximation, K * m) from `sii()` and `open_nl()`. The complete correction
  optimizes without difficulty, so the approximation is no longer needed.
  `sii()` now stops with an error for an unrecognized `desensitization` value
  instead of silently computing the ANSI SII.

* `open_nl()` now optimizes a negative `vent_floor` once, at the floor requested.
  Previously it also optimized with the floor at 0 dB and returned whichever solution
  had the higher raw SII, so the requested floor was not always honored and differences
  between floors could never be negative.

* `sii()` no longer floors a `prescription_target`'s insertion gain at 0 dB after
  output limiting. Negative insertion gain now lowers the speech level in the SII
  calculation, as it does in the loudness model; previously a gain cut below
  0 dB was invisible to the SII.

* Changed `open_nl()` default loudness cap to a normal-loudness cap. 
  The new cap uses `normal_speech_loudness()` to dynamically compute the normal-hearing loudness of unaided speech at the evaluation level. 
  The legacy behavior (PTA-based knots, reverse-slope penalty, and ABG adjustments) is still available via `cap_rule = "legacy"`.
