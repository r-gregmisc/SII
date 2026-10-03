# SII 1.3.0

* The Johnson & Dillon (2011) desensitization option is now named
  `"johnson2011_desensitized"` in `sii()` and `open_nl()`. The old name
  `"johnson2011_complete"` still works but gives a deprecation warning.

* Loudness is now computed by `calculate_loudness_audmod()`, a C++ port of the
  AUDMOD model (Bramslow, 2004) that matches the Auditory Modeling Toolbox
  (AMT 1.6.0) `bramslow2004` implementation at every stage. Tests compare it
  against AMT reference output for 23 cases.

* `open_nl()` gains `objective_sii`, which selects the SII the optimizer maximizes.
  The default is `"johnson2011_desensitized"`, the Johnson & Dillon (2011)
  desensitization correction; `"none"` optimizes the ANSI S3.5 SII.

* Removed the `desensitization_scale` argument from `sii()` and `open_nl()`.
  Desensitization is now either off (`"none"`, ANSI S3.5 SII) or the full
  Johnson & Dillon (2011) correction (`"johnson2011_desensitized"`); there is no
  partial blend. Passing `desensitization_scale` is an error.

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
