
# SII (development version)

* Changed `open_nl()` default loudness cap to a normal-loudness cap. 
  The new cap uses `normal_speech_loudness()` to dynamically compute the normal-hearing loudness of unaided speech at the evaluation level. 
  The legacy behavior (PTA-based knots, reverse-slope penalty, and ABG adjustments) is still available via `cap_rule = "legacy"`.
