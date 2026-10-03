## Update

This is an update from the previous CRAN release to version 1.3.0. Main changes
(see NEWS.md):

* The loudness model is now a C++ port of the AUDMOD model (Bramslow, 2004)
  that matches the Auditory Modeling Toolbox implementation stage by stage;
  regression tests against AMT reference output are included.
* `open_nl()` optimizes the Johnson & Dillon (2011) desensitized SII by default
  and uses a normal-hearing loudness cap (the previous rule remains available
  as `cap_rule = "legacy"`).
* The `"johnson2011_smoothed"` desensitization option was removed.

## Test environments

* local: Pop!_OS (Ubuntu), R x.y.z
* GitHub Actions: ubuntu-latest (release)
* win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes
