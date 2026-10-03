## Update

This is an update from the previous CRAN release to version 1.3.0. Main changes
(see NEWS.md):

* The loudness model is now a C++ port of the AUDMOD model (Bramslow, 2004)
  that matches the Auditory Modeling Toolbox implementation stage by stage;
  regression tests against AMT reference output are included.
* `open_nl()` optimizes the Johnson & Dillon (2011) desensitized SII by default
  and uses a normal-hearing loudness cap (the previous rule remains available
  as `cap_rule = "legacy"`).
* The `"johnson2011_smoothed"` desensitization option and the
  `desensitization_scale` argument were removed; desensitization is now
  either the ANSI SII or the full Johnson & Dillon (2011) correction,
  now named `"johnson2011_desensitized"` (the old name `"johnson2011_complete"`
  is accepted with a deprecation warning).

## Test environments

* local: Pop!_OS 24.04 (Ubuntu), R 4.3.3
* GitHub Actions: ubuntu-latest (release)
* win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes

The spell check may flag 'AUDMOD' (the name of a loudness model) and
Bramslow (an author's surname); both are spelled correctly.
