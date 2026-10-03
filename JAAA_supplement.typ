#set page(paper: "us-letter", margin: 1in, numbering: "1")
#set text(font: ("Linux Libertine",), size: 12pt, lang: "en", region: "US")
#set par(justify: true, leading: 2em, spacing: 2em,
  first-line-indent: (amount: 0.5in, all: true))
#set par.line(numbering: "1")
#show heading: set block(above: 2em, below: 1.2em)
#show bibliography: set par(first-line-indent: 0em, hanging-indent: 0.5in)
#set table(inset: 5pt, stroke: none)
#show table: set par(justify: false, leading: 0.65em)
#show table: set text(size: 11pt, hyphenate: false)

#block(width: 100%)[
#set par.line(numbering: none)
#set par(first-line-indent: (amount: 0em, all: true))
#align(center)[
  #text(size: 1.2em, weight: "bold")[Supplementary Material]

  #par(justify: false)[#text(hyphenate: false)[
    Does occluding the ear free loudness budget for high-frequency gain? \
    A modeling study of standard audiograms
  ]]

  Mark Shaver, Ph.D.
]
]

== S1. Validation of the C++ Loudness Engine

The AUDMOD specific-loudness engine, the `bramslow2004` implementation in
AMT 1.6.0 @majdak2022, was ported to C++ using `Rcpp` and validated at
three levels: port fidelity, input path consistency, and absolute
reference-free behavior.

First, port fidelity was established by comparing the C++ engine to the
AMT `bramslow2004` (AUDMOD) implementation stage by stage. Across 23
test cases, the maximum relative discrepancy at any stage of computation
was $5.71 times 10^(- 15)$. This comparison establishes that the C++
port reproduces AUDMOD; it does not bear on whether AUDMOD itself is
accurate.

Second, the input path for spectrum construction feeding the engine was
verified. The two independent routines used to compute normal-hearing
speech loudness in this work return identical values at 50, 65, and 80
dB SPL (3.1577, 9.0333, and 22.3887 sones, respectively). Evaluating
the 65 dB SPL speech spectrum on a 10--23990 Hz grid without
renormalization yields 9.0333 sones, whereas evaluation on a 20--15000
Hz grid with renormalization yields 9.0317 sones; this difference of
0.0016 sones shows that grid range and renormalization are immaterial.
Supplying a precomputed reference versus letting the wrapper build one
dynamically yields identical results for three sloping test audiograms
(13.2297, 20.7120, and 16.6072 sones).

Third, the absolute behavior of the model was verified using
reference-free checks, since the port and AMT would share any error.
Loudness correctly evaluates to zero below threshold: for normal
hearing, a 1 kHz tone remains silent up to +5 dB SPL, and for a test
audiogram with an 80 dB HL threshold at 4 kHz, a 4 kHz tone remains
silent up to 60 dB SPL. Recruitment is present and ordered by the 4 kHz
threshold across five test audiograms, including a reverse-slope
audiogram with a 20 dB HL threshold at 4 kHz. (These checks used
separate test audiograms; they concern the engine, not the audiograms
analyzed in the main text.) In normal hearing, the
loudness growth for a 1 kHz tone is 1.75 to 1.91 per 10 dB above 40
phons, which characterizes the model as mildly compressive relative to
the textbook expectation of a doubling per 10 dB.

The absolute sone scale is inherited from AUDMOD and has not been
independently verified against loudness judgments. An attempt to check
the 1 kHz / 40 dB SPL = 1 sone anchor was inconclusive: the R wrapper
interpolates the input spectrum linearly in dB across a log-frequency
grid, which is appropriate for the smooth, densely sampled speech
spectra used throughout this work but cannot faithfully represent a pure
tone. The smooth-spectrum control was stable at 9.0333 sones across
every input grid spacing tested, so the analyses reported in the main
text are unaffected. We do not claim the absolute scale is either
correct or incorrect.

== S2. The Open-NL Objective and Optimizer Settings

=== Objective

Open-NL optimizes six gain shifts, $bold(s) = (s_1, dots, s_6)$, one at
each octave frequency from 250 to 8000 Hz. Each shift is clamped to the
range $-60$ to $+30$ dB and added to the heuristic prescription
$g_k^h$ (Section S3), and the resulting gain is limited to the range
from the minimum-gain floor $g_"floor"$ (0 or $-10$ dB) to 80 dB:
$ g_k = min(80, max(g_"floor", g_k^h + s_k)). $
The optimizer minimizes
$ J(bold(s)) = -100 dot "SII"(bold(g)) + P_"anchor" + P_"rough"
  + P_"loud" + P_"bound" + P_"SPL" + P_"ABG", $
where the SII is the desensitized SII described below, so that
one point of $J$ corresponds to 0.01 SII. The three penalties that shape
the reported solutions are
$ P_"anchor" = 0.1 sum_k |s_k|, quad
  P_"rough" = 0.001 sum_(k=1)^5 (g_(k+1) - g_k)^2, quad
  P_"loud" = 2000 max(0, N - N_"cap"), $
where $N$ is the AUDMOD loudness of the aided speech spectrum in sones and
$N_"cap"$ is the loudness cap. In the anchor-off analyses the weight
0.1 in $P_"anchor"$ was set to zero; nothing else was changed.

The remaining terms are safeguards that were inactive or rarely engaged
in these analyses. $P_"bound" = 1000 sum_k [max(0, s_k - 30)^2 +
max(0, -s_k - 60)^2]$ acts on the unclamped search variables: because the
shifts applied to the gain are clamped, the objective is flat beyond
that range, and the penalty keeps the search from drifting there. $P_"SPL" = 2000 max(0, L - 110)$
penalizes an overall aided output $L$ above 110 dB SPL. $P_"ABG" =
sum_k max(0, s_k)^2$ is applied only to audiograms with an air-bone gap
(none in this study) and penalizes gain above the heuristic
prescription, which already incorporates the conductive correction. Two further terms, not
shown, constrain the gains at 50 and 80 dB SPL relative to the 65 dB SPL
solution (ordering of gain across levels and a maximum compression
ratio); because all optimizations here were performed at 65 dB SPL,
these were not active.

=== SII Evaluation within the Objective

The octave-frequency gains are interpolated linearly in log frequency to
the 21 bands of the ANSI S3.5-1997 critical-band procedure and applied to
the standard speech spectrum for normal vocal effort, scaled to 65 dB
SPL. The SII is then computed with the standard band-importance function,
the standard level distortion factor, and an external noise floor of
$-50$ dB, which leaves hearing threshold and self-speech masking as the
effective disturbances. Desensitization is applied to each band's
audibility $K_i$ through two functions of the band's sensorineural
threshold $T_i$ (dB HL):
$ m_i = 1 / (1 + e^(0.075 (T_i - 66))), quad p_i = T_i / 8 - 15. $
The desensitization correction, which is the optimizer's objective, is the
power mean $K'_i = (K_i^(p_i) + m_i^(p_i))^(1 \/ p_i)$; the ANSI SII,
reported alongside it, uses $K_i$ unchanged. For the thresholds used
here (0 to 110 dB HL), $p_i$ lies between $-15$ and $-1.25$. At mild to
moderate thresholds, where $p_i$ is strongly negative, the desensitization
correction behaves approximately as $min(K_i, m_i)$: once a band's
audibility exceeds its desensitization ceiling $m_i$, further audibility
earns little credit. At severe to profound thresholds the transition is
more gradual. Negative insertion gain lowers the
speech level in the SII calculation, as it does in the loudness model.

=== Optimizing the ANSI SII

To represent a fitting tuned to the uncorrected index that real-ear
systems display, the tightest-budget sweep and the iso-loudness control
were repeated with the optimizer maximizing the ANSI SII, everything
else unchanged. Tables S1 and S2 give the floor effect of these
solutions under the ANSI SII (what the display would show) and under the
desensitized SII.

#block(breakable: false, width: 100%)[
#strong[Table S1. Floor Effect of ANSI-Optimized Solutions: Audiogram
Family Sweep at the 0.5-Sone Budget]

#figure(
  align(center)[#table(
    columns: 5,
    align: (left, right, right, right, right),
    table.header([Audible edge], [ANSI (on)], [Desensitized (on)], [ANSI (off)], [Desensitized (off)],),
    table.hline(),
    [1000 Hz], [+0.079], [+0.013], [+0.087], [+0.014],
    [1500 Hz], [+0.027], [+0.004], [+0.038], [+0.005],
    [2000 Hz], [+0.010], [+0.004], [+0.017], [+0.001],
    [3000 Hz], [−0.001], [−0.001], [+0.002], [−0.001],
  )]
  , kind: table
  )

#par(first-line-indent: 0em)[#text(size: 10pt)[#emph[Note:] Means over
the four slopes at each edge. With the anchor penalty all 16 pairs
matched in loudness; without it, 5 did.]]
]

#block(breakable: false, width: 100%)[
#strong[Table S2. Floor Effect of ANSI-Optimized Solutions: Iso-Loudness
Control]

#figure(
  align(center)[#table(
    columns: 5,
    align: (left, right, right, right, right),
    table.header([Profile], [ANSI (on)], [Desensitized (on)], [ANSI (off)], [Desensitized (off)],),
    table.hline(),
    [N1], [+0.007], [+0.005], [+0.013], [+0.007],
    [N2], [+0.008], [+0.007], [0.000], [−0.005],
    [N3], [+0.003], [+0.002], [+0.007], [+0.008],
    [N4], [−0.005], [−0.001], [−0.001], [−0.003],
    [N5], [0.000], [0.000], [0.000], [0.000],
    [N6], [0.000], [0.000], [0.000], [0.000],
    [N7], [0.000], [0.000], [0.000], [0.000],
    [S1], [+0.006], [−0.001], [+0.023], [0.000],
    [S2], [+0.011], [−0.001], [+0.027], [−0.001],
    [S3], [−0.001], [0.000], [0.000], [0.000],
  )]
  , kind: table
  )

#par(first-line-indent: 0em)[#text(size: 10pt)[#emph[Note:] Only N1,
N2, S1, and S2 received negative gain; elsewhere the floor did not
engage and nonzero values reflect search variability. Without the
anchor penalty the −10 dB solution for S1 left 1.27 sones of the budget
unspent; all other pairs matched to within 0.04 sones.]]
]

In the sweep, the ANSI-optimized solutions matched in loudness had no
lower penalized objective at −10 dB than at 0 dB, so the search
converged as it did for the desensitized-SII objective.

=== Loudness Evaluation within the Objective

The aided spectrum at the six octave frequencies (the speech spectrum
level plus gain) is interpolated to a 10 Hz grid from 20 to 15000 Hz,
with skirts of 24 dB/octave below 250 Hz and above 8000 Hz, and
rescaled to the overall aided level. Any air-bone gap is subtracted
before the spectrum enters the AUDMOD engine. The audiogram supplied to
AUDMOD is the sensorineural threshold (threshold minus air-bone gap),
interpolated from the octave frequencies to AUDMOD's 13 audiogram
frequencies (125 to 12500 Hz); the uncomfortable loudness level is left
at the AUDMOD default of 120 dB HL, and the engine runs at a sampling
rate of 32 kHz with an 8192-point transform. The cap $N_"cap"$ was set
by each analysis: the listener's unaided loudness plus the budget in the
audiogram family sweep, and the loudness of the NAL-NL2 prescription in
the iso-loudness control.

=== Search Settings

The objective is minimized with the Nelder-Mead simplex method (R
`optim`, maximum 800 iterations, other settings at their defaults) from
multiple starting points. The unshifted heuristic ($bold(s) = bold(0)$)
is evaluated first and retained if no search improves on it. The first
search starts from a deterministic point: in each octave band, a nominal
shift toward the gain that would place a 65 dB SPL input 10 dB above
threshold, limited to the range 0 to 20 dB. Each further start adds independent uniform jitter
of $plus.minus 5$ dB to every parameter. The solution with the lowest
$J$ across all starts is returned, so the reported solution is
penalized-optimal and need not have the highest SII.

The random-number seed is set from the audiogram and the input level
(100 times the sum of the thresholds, plus the level), so repeated runs
are bit-identical and cannot be used to estimate variability, and a run
with more starts repeats the starting points of a run with fewer. The
number of starts can alter the prescribed gains, because the objective
is non-convex; the analyses used 20 starts, with 40 for the one
tightest-budget pair noted in the main text.

== S3. The Open-NL Heuristic Prescription

The heuristic prescription $g_k^h$ is a rule-based insertion-gain rule
built into Open-NL; it serves as the anchor for $P_"anchor"$ and as the
origin of the search. At a 65 dB SPL input, and with the settings used
here (fully occluded coupling, male, experienced bilateral user, no
measured loudness discomfort levels, no dead-region or distortion
information, severe-loss booster disabled), the gain at frequency $f$
is computed as follows.

+ #strong[Base gain.] $0.46 T_"SN" + C(f) dot T_"SN" \/ T$, where $T$ is
  the threshold, $T_"SN"$ its sensorineural part, and $C(f)$ equals $-8$,
  $-1$, $+3$, and $+1$ dB at 250, 500, 1000, and 2000 Hz and 0 dB from
  3000 Hz up, interpolated in log frequency.
+ #strong[Reverse-slope correction.] When the mean sensorineural
  threshold at 500 Hz and below exceeds the mean at 2000 Hz and above by
  more than 15 dB, $C(f)$ below 1000 Hz is blended toward $-10$ dB, fully
  so when the difference reaches 35 dB, with a weight that falls linearly
  in log frequency from 1 at 250 Hz to 0 at 1000 Hz.
+ #strong[Slope-dependent low-frequency penalty.] When the mean
  sensorineural threshold at 2000 Hz and above exceeds the mean at 500 Hz and below by more than
  15 dB, low-frequency gain is reduced by up to 15 dB, with the same
  250--1000 Hz taper. The reduction grows over the next 20 dB of slope
  and is phased out as the high-frequency mean rises from 70 to 95 dB HL,
  so that listeners with profound high-frequency loss retain
  low-frequency gain.
+ #strong[High-frequency soft limit.] Gain in excess of
  $30 + 0.4 max(0, T_"SN" - 60)$ dB is halved at frequencies where the
  sensorineural threshold is more than 25 dB worse than the best
  threshold at or below 1000 Hz. The limit is phased in between 2000 and 4000 Hz and, in
  threshold, over a further 20 dB.
+ #strong[Bandwidth weighting.] The gain is multiplied by 0.7 at 250 Hz,
  1.0 from 500 to 4000 Hz, 0.8 at 6000 Hz, and 0.5 at 8000 Hz.
+ #strong[Conductive correction.] 75% of the air-bone gap is added.
+ #strong[Limits.] The gain is floored at $-10$ dB. A maximum-output
  limit is then applied (it does not bind for any profile at a 65 dB SPL
  input), and the resulting gain is floored at 0 dB. This final 0 dB floor is why, as noted in the main
  text, any gain below 0 dB is a penalized shift.

Open-NL's compression stage leaves the 65 dB SPL gain unchanged by
construction, and demographic and coupling corrections are zero at the
settings used, so the rule above is the complete heuristic for these
analyses.

== S4. Robustness of the Floor Effect

Two further analyses, both optimizing the desensitized SII at 65 dB SPL with
20 random starts, tested whether the floor-effect results depend on the
loudness at which the comparison is made and on the random starts of the
search.

=== Floor Effect at the Normative Ceiling

For the four standard audiograms with audible low-frequency speech, the
optimization was repeated with the loudness cap set to $L_(c a p)$, the
loudness of unaided speech for a 0 dB HL listener (9.03 sones). Table S3
gives the results. No solution gave any band negative gain, with or
without the anchor penalty, so the floor did not engage and the
differences between floors reflect search variability alone.

#block(breakable: false, width: 100%)[
#strong[Table S3. Floor Effect with the Loudness Cap at the Normative
Ceiling (9.03 Sones)]

#figure(
  align(center)[#table(
    columns: 9,
    align: (left, left, right, right, right, right, right, right, right),
    table.header([Profile], [Anchor], [Budget], [NAL-NL2 use], [Sones (0 dB)],
      [Sones (−10 dB)], [SII (0 dB)], [SII (−10 dB)], [Floor effect],),
    table.hline(),
    [N1], [on], [2.53], [0.54], [9.03], [9.03], [0.890], [0.896], [+0.006],
    [N1], [off], [2.53], [0.54], [8.93], [9.01], [0.915], [0.915], [0.000],
    [N2], [on], [5.94], [1.75], [6.43], [6.26], [0.836], [0.824], [−0.012],
    [N2], [off], [5.94], [1.75], [6.49], [6.20], [0.846], [0.846], [0.000],
    [S1], [on], [2.97], [0.58], [8.74], [8.74], [0.807], [0.807], [0.000],
    [S1], [off], [2.97], [0.58], [7.95], [7.70], [0.832], [0.833], [0.000],
    [S2], [on], [6.32], [1.71], [5.69], [5.59], [0.589], [0.590], [+0.001],
    [S2], [off], [6.32], [1.71], [5.23], [5.23], [0.599], [0.599], [0.000],
  )]
  , kind: table
  )

#par(first-line-indent: 0em)[#text(size: 10pt)[#emph[Note:] Budget is
$L_(c a p) - L_0$ in sones; NAL-NL2 use is the loudness NAL-NL2 adds
above $L_0$. Sones are the aided loudness reached at each floor; SII is
the desensitized SII. No band received negative gain in any
solution.]]
]

=== Search Variability

The optimizer's random-number seed is fixed by the audiogram and level,
so repeated runs are identical. To estimate how much a solution depends
on the random starts, the floor comparison (anchor on) was repeated with
the default seed and five further seeds for the four 1000 Hz edge
audiograms at the 0.5-sone budget and for N1, N2, S1, and S2 at NAL-NL2
loudness (Table S4). The default-seed runs reproduced the stored
solutions exactly. The pooled within-case standard deviation of the
floor effect was 0.0037 (2 SD = 0.0075). Of the 48 pairs, 40 matched in
loudness to within 0.01 sones. In five of the remaining eight the
−10 dB solution was the quieter (by up to 0.17 sones), so their floor
effects, if anything, understate the benefit; in the other three it was
louder by at most 0.016 sones.

#block(breakable: false, width: 100%)[
#strong[Table S4. Desensitized-SII Floor Effect across Six Random Seeds
(Anchor Penalty On)]

#figure(
  align(center)[#table(
    columns: 9,
    align: (left, right, right, right, right, right, right, right, right),
    table.header([Case], [Seed 0], [1], [2], [3], [4], [5], [Mean], [SD],),
    table.hline(),
    [1000 Hz, 20 dB/oct], [+0.011], [+0.014], [+0.005], [+0.015], [+0.010], [+0.011], [+0.011], [0.004],
    [1000 Hz, 30 dB/oct], [+0.015], [+0.013], [+0.012], [+0.018], [+0.020], [+0.016], [+0.016], [0.003],
    [1000 Hz, 40 dB/oct], [+0.014], [+0.016], [+0.015], [+0.016], [+0.013], [+0.013], [+0.015], [0.001],
    [1000 Hz, 50 dB/oct], [+0.015], [+0.014], [+0.015], [+0.014], [+0.019], [+0.014], [+0.015], [0.002],
    [N1], [−0.001], [−0.001], [−0.007], [+0.009], [+0.010], [+0.003], [+0.002], [0.007],
    [N2], [−0.002], [−0.010], [−0.005], [+0.002], [−0.002], [+0.007], [−0.002], [0.006],
    [S1], [−0.004], [−0.005], [−0.002], [−0.003], [−0.001], [−0.002], [−0.003], [0.002],
    [S2], [+0.001], [−0.002], [0.000], [−0.001], [0.000], [−0.002], [−0.001], [0.001],
  )]
  , kind: table
  )

#par(first-line-indent: 0em)[#text(size: 10pt)[#emph[Note:] The 1000
Hz cases are sweep audiograms at the 0.5-sone budget; N1 to S2 are at
NAL-NL2 loudness. Seed 0 is the package default; all runs used 20
starts, so the seed-0 value for the 50 dB/octave case differs slightly
from the 40-start value in the main text.]]
]

== S5. Reproducibility

All analyses were run in R from the repository cited in the Data
Availability section. Table S5 lists the script that produces each
reported result; all scripts are in `reproducibility_scripts/` and are
run from the repository root.

#block(breakable: false, width: 100%)[
#strong[Table S5. Scripts Producing Each Result]

#figure(
  align(center)[#table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([Result], [Script (in order of execution)]),
    table.hline(),
    [Table 1 audiograms; NAL-NL2 gains], [`bisgaard_profiles.R` (data; gains exported from NAL-NL2 v2.0, dll v2.15)],
    [Table 2; Figure 1; NAL-NL2 loudness], [`rerun_bisgaard_profiles.R`; `fig_jaaa.R`],
    [Tables 4 and 5; Table S2], [`rerun_bisgaard_profiles.R`],
    [Table 3; resolution limit], [`rerun_complete_objective.R`],
    [Figure 2], [`fig_jaaa.R` (after `rerun_complete_objective.R`)],
    [Low- vs high-frequency rescoring; unspent budget], [`mechanism_check_complete.R`],
    [Table S1], [`rerun_ansi_objective.R`],
    [Tables S3 and S4; search variability; floor at the normative ceiling], [`floor_robustness.R`],
  )]
  , kind: table
  )
]

#set bibliography(style: "jaaa.csl", title: [References])
#bibliography("jaaa_refs.bib")
