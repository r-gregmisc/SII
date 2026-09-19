# vent_floor does not prescribe at the requested floor

When `vent_floor < 0`, `open_nl()` runs `optimize_level` twice — once with the requested floor and once with the floor forced to 0 (lines 381-395 for 65 dB, and 404-418 for non-65 dB levels). It then returns whichever branch has the higher raw SII from `compute_sii()`.

**Consequences:**
1. The returned prescription may use a 0 dB floor despite the argument explicitly requesting a negative floor.
2. Any difference computed between `vent_floor = -10` and `vent_floor = 0` is rectified to `max(0, delta)`.
3. Branch selection uses raw SII while within-branch selection uses the penalized objective.

**Minimal Reproducible Example:**
```R
library(SII)
# When we ask for -10 dB vent floor, we might get 0 dB anyway if the raw SII branch at 0 dB is higher.
freqs <- c(250, 500, 1000, 2000, 4000, 8000)
# Use a steeply sloping profile where lowering gain at 0 dB floor might yield higher raw SII 
# than the optimal solution constrained at -10 dB floor.
htl <- c(10, 10, 10, 50, 90, 110)
res_0 <- open_nl(speech = 65, threshold = htl, freq = freqs, loss = rep(0, 6), vent_floor = 0)
res_10 <- open_nl(speech = 65, threshold = htl, freq = freqs, loss = rep(0, 6), vent_floor = -10)
# The gains may be identical, meaning vent_floor = -10 did not prescribe at the requested floor.
identical(res_0$gain, res_10$gain)
```

**References:**
- `R/open_nl.R` lines 381-395 (65 dB level logic)
- `R/open_nl.R` lines 404-418 (non-65 dB level logic)
