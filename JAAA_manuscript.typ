#let horizontalrule = line(start: (25%,0%), end: (75%,0%))
#set par.line(numbering: "1")
#set par(first-line-indent: (amount: 0.5in, all: true), leading: 2em, spacing: 2em)
#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

#set table(
  inset: 6pt,
  stroke: none
)

#show figure.where(
  kind: table
): set figure.caption(position: top)

#show figure.where(
  kind: image
): set figure.caption(position: bottom)

#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}
#let conf(
  title: none,
  subtitle: none,
  authors: (),
  keywords: (),
  date: none,
  abstract: none,
  cols: 1,
  margin: (x: 1.25in, y: 1.25in),
  paper: "us-letter",
  lang: "en",
  region: "US",
  font: (),
  fontsize: 11pt,
  sectionnumbering: none,
  pagenumbering: "1",
  doc,
) = {
  set document(
    title: title,
    author: authors.map(author => content-to-string(author.name)),
    keywords: keywords,
  )
  set page(
    paper: paper,
    margin: margin,
    numbering: pagenumbering,
    columns: cols,
    )
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)

  place(top, float: true, scope: "parent", clearance: 4mm)[
  #if title != none {
    align(center)[#block(inset: 2em)[
      #text(weight: "bold", size: 1.5em)[#title]
      #(if subtitle != none {
        parbreak()
        text(weight: "bold", size: 1.25em)[#subtitle]
      })
    ]]
  }

  #if authors != none and authors != [] {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  #if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  #if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[Abstract] #h(1em) #abstract
    ]
  }
  ]

  doc
}




#show: doc => conf(
  title: none,
  authors: (),
  font: ("Linux Libertine",),
  fontsize: 12pt,
  pagenumbering: "1",
  cols: 1,
  doc,
)

// ---- JAAA title page --------------------------------------------------
// Per JAAA Author Instructions (audiology.org, updated 2024): page one
// carries the submission date, full title, author names with academic
// degrees, institutional affiliations, corresponding-author contact
// details, prior-presentation information (if any), and acknowledgments
// or grant numbers. Fill in the bracketed placeholders and delete this
// comment block and the page break below if the submission portal
// collects this information separately instead.

#block[
#set par.line(numbering: none)
#align(center)[
  #text(size: 1.3em, weight: "bold")[
    Loudness budget constraints on high-frequency amplification in
    precipitous hearing loss
  ]

  #v(1.5em)
  Mark Shaver, Ph.D.

  Department of Communication Sciences and Disorders \
  Wichita State University \
  Wichita, KS, USA

  #v(1.5em)
  #par(justify: false)[
    #strong[Corresponding author:] Mark Shaver, Ph.D. \
    517 Oakwood St. \
    Rose Hill, KS 67133 \
    Phone: 1-316-208-9588 \
    Email: mark.shaver\@wichita.edu
  ]

  #v(1.5em)
  #strong[Date of submission:] #text(style: "italic")[\[date\]]

  #v(1em)
  #strong[Prior presentation:] None

  #v(1em)
  #strong[Acknowledgments / funding:] No grant support was received for
  this work; see Acknowledgments section.
]
]

#pagebreak()


== Abstract
<abstract>
#strong[Background:] In precipitous high-frequency hearing loss,
restoring high-frequency audibility is difficult, usually attributed to
the fitting rationale or to physiological damage.

#strong[Purpose:] To test a structural explanation: unamplified speech
in the residual low frequencies consumes much of the loudness budget before any gain is prescribed.

#strong[Research Design:] Computational modeling with the AUDMOD
specific-loudness model and the Speech Intelligibility Index (SII).

#strong[Study Sample:] Seven canonical audiometric profiles and sixteen
synthetic audiograms.

#strong[Data Collection and Analysis:] The loudness budget was
decomposed at 50, 65, and 80 dB SPL. At 65 dB SPL, gains were optimized
with minimum insertion-gain floors of 0 and -10 dB, in a sweep of
audible edge, slope, and loudness budget and in an iso-loudness control
matched to NAL-NL2. Solutions optimized
on a smoothed desensitized SII were scored with it, the published
Johnson and Dillon correction, and the ANSI SII, with and without the
optimizer's anchor penalty.

#strong[Results:] For profile A4 at 65 dB SPL, unamplified speech
consumed 64% of the normative ceiling. At the tightest budget
and a 1000 Hz audible edge, relaxing the floor improved the SII by 0.017
to 0.050 across metrics (resolution limit 0.006); at higher
edges the benefit was at most 0.012. Under the published correction,
the iso-loudness floor effect was +0.045 for moderate sloping profile A3
and negligible for precipitous profiles A4 and A5. Without the anchor penalty, A4 and A5 gained 0.037 to 0.086 under
the smoothed and ANSI SII but at most 0.006 under the published
correction. The benefit came from high-frequency gain funded by a
low-frequency cut.

#strong[Conclusions:] Residual low-frequency hearing consumes most of
the loudness budget before gain is applied. Whether relaxing the floor
helps depends on how strongly desensitization discounts high-frequency
audibility. Because negative low-frequency
insertion gain requires an unvented fitting, the modeled benefit does
not justify sacrificing venting unless desensitization is mild.

#strong[Clinical Relevance Statement:] In precipitous loss, freeing the
loudness budget consumed by residual low-frequency hearing requires an
unvented fitting and, under current desensitization models, adds little
intelligibility. Open fittings remain an appropriate default, and
frequency lowering may warrant consideration when more high-frequency
information is needed.

== Introduction
<introduction>
In the fitting of precipitous or profound high-frequency hearing loss,
achieving adequate high-frequency audibility without exceeding normative
loudness targets is a central clinical challenge. Historically, the
failure to restore high-frequency audibility has been attributed to the
inherent physiological damage of the auditory periphery---specifically,
hearing-loss desensitization and dead regions @moore2001, which render
high-frequency amplification for a severe loss or greater effectively
useless for speech recognition @ching1998@hogan1998. Consequently, modern
prescriptive rationales like NAL-NL2 @keidser2011 deliberately limit
high-frequency gain for profound thresholds to avoid prescribing "wasted"
amplification.

While desensitization dictates the utility of high-frequency
gain, it is proposed that the fundamental arithmetic of broadband
loudness summation acts as a parallel, independent structural constraint
on the capacity to provide that gain. For a given audiogram and
input level, unamplified speech inherently produces a baseline quantity
of loudness ($L_0$) through residual hearing. If a patient's overall
target loudness is constrained by a normative ceiling ($L_(c a p)$), the
model-predicted loudness budget available to "purchase" high-frequency
audibility via prescriptive gain is defined as $L_(c a p) - L_0$.
Because this relationship is governed entirely by the auditory periphery
and the acoustic speech spectrum, it acts as a fundamental boundary
condition that heavily constrains loudness-based rationales (e.g.,
NAL-NL2) and any theoretical attempt at intelligibility maximization.

While patient preference and some audiological paradigms often favor
preserving or amplifying low-frequency cues in profound loss because
they are the only remaining regions of robust functional hearing, the
standard ANSI S3.5-1997 Speech Intelligibility Index (SII) @ansi1997
assigns the bulk of its importance weighting to the 1-4 kHz speech
bands, with relatively little weight applied below 500 Hz. Consequently,
an unconstrained intelligibility-maximizing algorithm operating under a
strict loudness budget will tend to attenuate low-frequency audibility
to fund high-frequency gain. While it is a mathematical axiom that
relaxing a constraint in an optimization algorithm yields a higher
theoretical optimum, the clinical relevance lies in quantifying the
magnitude of this trade-off for realistic audiometric profiles, and in
whether it survives when the index is corrected for desensitization. By
framing this behavior as an efficiency statement relative to an
absolute budget, this analysis quantifies the degree to which
"broadband loudness crowding-out" limits high-frequency restoration,
investigating whether it is uniquely tied to precipitous losses or
represents a general property of near-normal low-frequency hearing.

== Methods
<methods>
=== The AUDMOD Specific-Loudness Model
<the-audmod-specific-loudness-model>
To isolate the model-predicted loudness constraints operating on the
speech spectrum, the AUDMOD specific-loudness model @bramslow1993@bramslow2004 was
utilized. This model converts acoustic excitation patterns into specific
loudness (sones/ERB) and integrates them across the frequency spectrum
to predict overall broadband loudness. By benchmarking the raw,
unamplified long-term average speech spectrum (LTASS) through this model
using the seven standard hypothetical audiometric profiles established
by #cite(<johnson2011>, form: "prose"), the baseline loudness ($L_0$)
natively generated by residual hearing was established. Throughout this
work the LTASS is the ANSI S3.5-1997 standard speech spectrum for normal
vocal effort @ansi1997, scaled to the evaluation level; the same
spectrum feeds both the loudness model and the SII calculation.

=== Study Sample and Audiometric Profiles
<study-sample-and-audiometric-profiles>
The study utilizes seven canonical audiometric profiles (A1--A7)
representing standard clinical configurations (Table 1). For profiles A6
(Mixed) and A7 (Conductive), the conductive air-bone gap component is
modeled in the AUDMOD specific-loudness engine as a linear attenuation
block that strictly subtracts from the aided speech spectrum before it
enters the cochlear simulation.

#strong[Table 1. Canonical Audiometric Profiles (dB HL)]

#figure(
  align(center)[#table(
    columns: 9,
    align: (left,left,left,left,left,left,left,left,left,),
    table.header([Profile], [Description], [250], [500], [1000], [2000], [4000], [8000], [ABG],),
    table.hline(),
    [A1], [Mild], [15], [20], [30], [40], [50], [60], [0],
    [A2], [Reverse slope], [60], [50], [40], [30], [20], [15], [0],
    [A3], [Moderate sloping], [10], [20], [40], [50], [55], [60], [0],
    [A4], [Mod-severe precip.], [0], [0], [10], [40], [70], [80], [0],
    [A5], [Profound precip.], [10], [10], [20], [60], [80], [100], [0],
    [A6], [Mixed], [50], [55], [60], [65], [75], [80], [30 dB],
    [A7], [Conductive], [50], [50], [50], [50], [50], [50], [50 dB],
  )]
  , kind: table
  )

=== The Open-NL Computational Instrument
<the-open-nl-computational-instrument>
To compute the theoretical limits of high-frequency amplification and
map the boundary of achievable gain, Open-NL, a modular computational
testbed, was employed. Open-NL couples a multi-start Nelder-Mead SII
optimizer to the specific-loudness engine. Rather than serving as a
clinical prescription, Open-NL functions here strictly as an analytical
instrument.

For the purposes of this study, all input speech was calibrated to the
standard ANSI S3.5-1997 Long-Term Average Speech Spectrum (LTASS)
@ansi1997. Because the analysis focuses entirely on average
conversational speech, the Wide Dynamic Range Compression (WDRC)
capabilities of Open-NL were bypassed, reducing the optimizer to a
single-level linear insertion gain solver at 65 dB SPL.

The optimizer was subjected to a global minimum insertion gain
constraint across all frequency bands (the `vent_floor` parameter). A
negative insertion gain floor represents the passive insertion loss of
an occluding earmold (the Real-Ear Occluded Response minus the Real-Ear
Unaided Response). Measured insertion loss is inherently
frequency-dependent and is typically smallest at the lowest frequencies,
even for completely unvented molds @kuk2009. The flat -10 dB floor used
here is therefore an idealization that is likely optimistic in the lowest frequency bands, rather than a model of any specific earmold. While
mathematically enforced as a global floor, for sensorineural profiles
with sloping configurations the floor binds only at the low frequencies,
with A2, a reverse-slope profile, the exception. Baseline clinical
targets were generated using NAL-NL2 Version 2 software @keidser2011 at
65 dB SPL for a symmetrical, bilateral fitting for an experienced user
of unknown gender. To isolate the rationale's fundamental prescription
for the audiogram from the secondary acoustic effects of venting, the
targets were intentionally generated using a fully occluded (\#13
tubing) coupling rather than an open fitting. While an open fitting is
the clinical standard of care for these profiles, generating NAL-NL2
targets with an open coupling instructs the software to automatically
cut low-frequency prescribed gain. Utilizing an occluded setting ensures
the baseline targets reflect the rationale's true theoretical intent.
However, it must be noted that because NAL-NL2 was parameterized for a
bilateral fitting, the rationale automatically applied a binaural
loudness correction that systematically lowers prescribed gain. Because
the computational instruments utilized in this analysis are strictly
monaural, this introduces a methodological mismatch. While this binaural
correction contributes slightly to NAL-NL2's lower overall predicted
loudness, the magnitude of the discrepancy is small relative to the
structural boundaries of the $L_(c a p) - L_0$ budget.

=== C++ Instrument Validation
<c-instrument-validation>
Because Open-NL evaluates tens of thousands of candidate gain curves
during optimization, evaluating loudness via external Python or MATLAB
calls introduces prohibitive computational overhead. To achieve
microsecond evaluation times, the AUDMOD specific-loudness engine (AMT
1.6.0 @majdak2022, `bramslow2004`) was ported entirely to C++ using
`Rcpp`.

The C++ engine was validated at three distinct levels: port fidelity,
input path consistency, and absolute reference-free behavior.

First, port fidelity was established by comparing the C++ engine to the
AMT `bramslow2004` (AUDMOD) implementation stage-by-stage. Across 23
test cases, the maximum relative discrepancy at any stage of computation
was $5.71 times 10^(- 15)$. This comparison establishes that the C++
port reproduces AUDMOD; it does not bear on whether AUDMOD itself is
accurate.

Second, the input path for spectrum construction feeding the engine was
verified. The two independent routines used to compute normal-hearing
speech loudness in this work return identical values at 50, 65, and 80
dB SPL (yielding 3.1577, 9.0333, and 22.3887 sones, respectively).
Evaluating the 65 dB SPL speech spectrum on a 10--23990 Hz grid without
renormalization yields 9.0333 sones, whereas evaluation on a 20--15000
Hz grid with renormalization yields 9.0317 sones; this difference of
0.0016 sones demonstrates that grid range and renormalization are
immaterial. Furthermore, supplying a precomputed reference versus
letting the wrapper build one dynamically yields identical results for
profiles A1 (13.2297 sones), A4 (20.7120 sones), and A5 (16.6072 sones).

Third, the absolute behavior of the model was verified using
reference-free checks, as the port and AMT would share any error.
Loudness correctly evaluates to zero below threshold: for normal
hearing, a 1 kHz tone remains silent up to +5 dB SPL, and for profile
A5, 4 kHz remains silent up to 60 dB SPL against an 80 dB HL threshold.
Recruitment is present and ordered by threshold at 4 kHz across profiles
A1--A5; the apparent non-monotonicity across profiles reflects the
audiometric configuration, not severity (e.g., A2 is a reverse-slope
profile with a 20 dB HL threshold at 4 kHz). In normal hearing, the
loudness growth for a 1 kHz tone is 1.75 to 1.91 per 10 dB above 40
phons, which characterizes the model as mildly compressive relative to
the textbook expectation of a doubling per 10 dB.

A notable limitation is that the absolute sone scale is inherited from
AUDMOD and has not been independently verified against loudness
judgments. An attempt to check the 1 kHz / 40 dB SPL = 1 sone anchor was
inconclusive: the R wrapper interpolates the input spectrum linearly in
dB across a log-frequency grid, which is appropriate for the smooth,
densely sampled speech spectra used throughout this work but cannot
faithfully represent a pure tone. The smooth-spectrum control was stable
at 9.0333 sones across every input grid spacing tested, ensuring the
analyses reported here are unaffected. We do not claim the absolute
scale is either correct or incorrect.

=== Intelligibility Metrics
<intelligibility-metrics>
Three versions of the SII were used. The #emph[ANSI SII] is the index
as standardized @ansi1997, with no correction for desensitization. The
#emph[complete] desensitized SII applies the published
#cite(<johnson2011>, form: "prose") correction, which combines each
band's audibility with a level-dependent desensitization factor through
a power mean. The #emph[smoothed] desensitized SII is Open-NL's
approximation to that correction: it multiplies each band's audibility
by the same desensitization factor instead. The complete formulation is
discontinuous where the exponent of its power mean passes through zero,
which impedes simplex search, so the smoothed version serves as the
optimizer's objective.

Every solution reported here was optimized once, on the smoothed SII,
and then scored with all three metrics. Because the optimizer never
targets the complete or ANSI SII, nothing guarantees that relaxing the
floor improves either of them; a negative floor effect under those
metrics is therefore a genuine result rather than solver noise.

=== Optimization Procedure
<optimization-procedure>
The underlying optimization routine utilized a multi-start Nelder-Mead simplex algorithm over six free parameters: a gain shift at each audiometric octave frequency from 250 to 8000 Hz, applied on top of the Open-NL heuristic prescription and interpolated logarithmically across the 21 analysis bands. All Open-NL runs used the package defaults for
the heuristic prescription: a fully occluded coupling with no vent
correction, the severe-loss booster disabled, and no demographic
adjustments.

The solutions generated are penalized-optimal rather than strictly
SII-optimal. Specifically, the optimizer maximizes a nine-term penalized
objective function, not raw SII. The objective consists of the SII
(scaled by 100) minus eight penalty terms: an anchor penalty
(`sum(abs(shifts)) * 0.1`) which acts as an L1 shrinkage toward the
Open-NL heuristic prescription, a roughness penalty
(`sum(diff(gain_oct)^2) * 0.001`), a loudness hinge penalty scaled at
2000 per sone over the cap, and additional out-of-bounds, SPL, order,
compression ratio (CR), and air-bone gap (ABG) terms (see `R/open_nl.R`
lines 268-284).

To mitigate local minima, multi-start initialization was employed across
a bounded parameter grid, and the solver retains the highest value of
the penalized objective, not the highest SII. Because the objective
includes the anchor penalty (an L1 shrinkage toward the heuristic
prescription) and the roughness penalty, additional restarts improve the
objective and can return solutions with lower SII.

Additionally, the number of random restarts (`open_nl_starts`) is a
fixed setting (set to 20 unless stated otherwise) whose value alters
the prescribed gains due to the non-convex parameter space. (Note that
because the random number generator seed is deterministic based on the
audiogram and level, repeated runs are bit-identical and cannot be used
to estimate variability. For the same reason, a run with 40 restarts
repeats the first 20 exactly and adds 20 more, so its penalized
objective can only equal or improve on the 20-restart result.)

The anchor penalty charges 0.1 objective points per dB of shift away
from the heuristic prescription, which the optimizer floors at 0 dB
before shifts are applied, so driving two low-frequency bands to the
-10 dB floor costs at least 0.02 in SII-equivalent units. Because this
is the same order as the floor effects of interest, the tightest-budget
sweep and the iso-loudness control were repeated with the anchor weight
set to zero (20 restarts). Without the anchor, the only remaining
regularization is the weak roughness penalty, so these solutions
indicate what is attainable in principle rather than realistic
prescriptions; anchor-on and anchor-off results are reported together
as a bracket.

== Results
<results>
=== Loudness Budget Decomposition
<loudness-budget-decomposition>
To establish the model-predicted loudness constraints operating on
high-frequency amplification, the unamplified loudness ($L_0$) produced
by speech across three conversational input levels (50, 65, and 80 dB
SPL) was first computed. This baseline was then compared against a
normative broadband loudness ceiling ($L_(c a p)$) for each level.

To avoid arbitrary definitions of tolerance, the normative target
ceilings ($L_(c a p)$) are strictly defined as the normal-hearing
loudness of unaided speech at the evaluation level. When the 50, 65, and
80 dB SPL long-term average speech spectra are processed through the
specific-loudness engine for a 0 dB HL profile, the model predicts
overall loudnesses of 3.16, 9.03, and 22.39 sones, respectively. These
ceilings are identical for all listeners and are not listener-specific.
The difference ($L_(c a p) - L_0$) therefore represents the remaining
model-predicted loudness budget available to "purchase" high-frequency
audibility via prescriptive gain before exceeding normal-hearing
loudness limits.

An empirical anchor for this ceiling would be preferable to a normative
one, so we tested whether an established rationale provides one. It does
not: NAL-NL2-prescribed aided loudness for 65 dB SPL speech, expressed
as a fraction of the normative ceiling, scatters by nearly a factor of
two with no consistent value (0.46 for A1, 0.39 for A2, 0.40 for A3,
0.73 for A4, and 0.61 for A5). Because NAL-NL2 optimizes loudness
against its own criteria rather than targeting a fixed proportion of
normal-hearing loudness, it cannot be used to calibrate this parameter.

$L_(c a p)$ is therefore a modelling assumption, not a measured
quantity. Because true loudness discomfort or target loudness can vary
significantly across individual patients and fitting rationales,
analyzing a single fixed normative cap for 65 dB SPL speech (e.g., 9.03
sones) fails to capture the full optimization boundary. This is why the
audiogram family sweep evaluates four different loudness budgets per
listener rather than a single fixed value: the sweep across budgets is
the sensitivity analysis for this assumption, and conclusions that hold
across the range do not depend on the particular value chosen.

Table 2 presents this decomposition for the seven canonical audiometric
profiles. For mild (A1) or moderate sloping (A3) profiles, unamplified
speech consumes a minority of the normative loudness budget across all
levels. This leaves ample capacity for prescriptive algorithms to apply
positive insertion gain across the frequency spectrum.

#strong[Table 2. Loudness Budget Decomposition (Sones) across
Audiometric Profiles at 50, 65, and 80 dB SPL]

#figure(
  align(center)[#table(
    columns: (12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%),
    align: (left,left,left,left,left,left,left,left,),
    table.header([Profile], [Description], [$L_0$ (50)], [$L_(c a p)$
      (50)], [$L_0$ (65)], [$L_(c a p)$ (65)], [$L_0$
      (80)], [$L_(c a p)$ (80)],),
    table.hline(),
    [A1], [Mild], [0.40], [3.16], [2.65], [9.03], [9.22], [22.39],
    [A2], [Reverse
    Slope], [0.02], [3.16], [1.33], [9.03], [6.72], [22.39],
    [A3], [Moderate
    Sloping], [0.43], [3.16], [2.29], [9.03], [8.01], [22.39],
    [A4], [Mod-Severe
    Precipitous], [1.85], [3.16], [5.77], [9.03], [15.25], [22.39],
    [A5], [Profound
    Precipitous], [1.16], [3.16], [4.34], [9.03], [12.10], [22.39],
    [A6], [Mixed], [0.00], [3.16], [0.00], [9.03], [0.17], [22.39],
    [A7], [Conductive], [0.00], [3.16], [0.00], [9.03], [0.28], [22.39],
  )]
  , kind: table
  )

#figure(image("figures/Figure1_Loudness_Budget.png"),
  caption: [
    Fraction of the normative loudness ceiling consumed by unamplified
    speech, for the seven canonical profiles (defined in Table 1) at
    input levels of 50, 65, and 80 dB SPL. The ceiling is the loudness
    of unaided speech for a listener with typical hearing at that level,
    and is identical across profiles. The remainder of each bar's height
    to 100% is the budget available to purchase high-frequency
    audibility before any gain is prescribed.
  ]
)

However, a structural bottleneck emerges in precipitous profiles (A4 and
A5) across the entire dynamic range. As illustrated in Figure 1, the
fraction of the loudness budget consumed by unamplified speech rises
with input level for every profile, so the constraint tightens as speech
gets louder. Profile A4 consumes 58.5%, 63.9%, and 68.1% of the ceiling
at 50, 65, and 80 dB SPL respectively---4.6, 2.2, and 1.7 times the
fraction consumed by the mild profile (A1: 12.7%, 29.3%, 41.2%), and
well above the moderate sloping (A3: 13.7%, 25.3%, 35.8%) and reverse
slope (A2: 0.7%, 14.7%, 30.0%) profiles. Profile A5 consumes a smaller
fraction than A4 (36.6%, 48.1%, 54.0%) despite being the more profound
loss; this is because A5's high-frequency thresholds are so elevated
that unamplified speech is largely inaudible there and contributes
little loudness. Crucially, if a prescriptive formula enforces a rigid
low-frequency insertion gain floor of 0 dB (preventing attenuation),
these $L_0$ values cannot be reduced. What remains is thus far short of
the high-frequency gain required to cross the profound high-frequency
thresholds, so high-frequency audibility is crowded out by residual
low-frequency hearing at all input levels.

=== The Audiogram Family Sweep
<the-audiogram-family-sweep>
A defect in the `open_nl()` routine caused an earlier version of this
minimum-gain floor contrast to report a rectified difference rather than
a true effect. When called with a negative insertion floor, the function
executed a dual-run branch that evaluated the optimization at both the
requested floor and a strict 0 dB floor, automatically returning
whichever yielded the higher raw speech intelligibility index---meaning
branch selection used raw SII, whereas selection within each branch used
the penalized objective (see `R/open_nl.R` lines 381--395 for 65 dB SPL
and 404--418 for other levels). Consequently, the published difference
between the -10 dB and 0 dB floors was not `SII(-10) - SII(0)` but
`max(0, SII(-10) - SII(0))`. Across all 192 paired cells of the original
audiogram family analysis, not one difference took a negative value;
this is impossible in a genuine comparison because the 0 dB feasible set
is contained within the -10 dB feasible set, meaning negative
differences must occur wherever the true effect is small relative to
optimizer precision. This bounding explains why 63 of the 192 paired
cells appeared as exactly zero. These zeros were simply 0 dB solutions
differenced against themselves rather than legitimate null results.
Their frequency rose with the audible edge frequency, from 31% of cells
at 1000 Hz to 61% at 3000 Hz, consistent with the 0 dB branch winning
most often where relaxing the floor helps least. Because this defect was
isolated to branch selection and did not compromise the underlying
loudness engine or the optimizer itself, the analysis code for this
paper disables the dual-run branch so that each floor is optimized
exactly once at the floor requested (the original package behavior is
documented in a separate issue). The affected results have been
recomputed under this corrected methodology and are reported below as
side-by-side solutions with their achieved loudness. The original
analysis also varied the strength of the desensitization penalty; those
conditions changed the optimizer's objective rather than only the
scoring, and are not reported.

Sixteen synthetic audiograms crossing four audible edge frequencies
(1000, 1500, 2000, 3000 Hz) with four high-frequency slopes (20, 30, 40,
50 dB/octave) were evaluated at four loudness budgets (0.5, 1, 2, and 3
sones above each listener's own unaided loudness) and two minimum-gain
floors (0 and -10 dB), giving 64 paired cells. Each floor was optimized
once, on the smoothed SII, at the floor requested with 20 random
restarts, and each solution was scored with the smoothed, complete, and
ANSI SII.

At the tightest budget the loudness cap should bind at both floors, yet
six of the 16 pairs initially differed in achieved loudness by more
than 0.001 sones. These six were re-optimized at both floors with 40
restarts. Two became matched, and a third (0.001 sones) was matched in
all but name; the other three still stopped short of the cap at the
-10 dB floor, by 0.004 to 0.028 sones. With the anchor penalty removed,
two of those three reached the cap to within 0.0002 sones, indicating
that the shortfall was an optimum of the penalized objective, in which
spending the last of the budget cost more in anchor penalty than it
gained in SII, rather than a failure to converge. The 40-restart
solutions replace the originals in what follows.

After this rerun, 41 of the 64 paired cells match in achieved loudness
to within 0.001 sones (12, 12, 9, and 8 of 16 at budgets of 0.5, 1, 2,
and 3 sones). Where a pair is unmatched it is usually the -10 dB
solution that leaves budget unspent, and this becomes more common as
the budget loosens and the cap binds less tightly.

A negative difference between floors is impossible for a genuine
optimum of the optimized metric, since the 0 dB feasible set is
contained within the -10 dB set. Across the 41 matched pairs, 15
smoothed-SII differences are negative; their median magnitude is 0.0008
and the largest is 0.0056. We take the maximum, rounded to 0.006, as the
optimizer's resolution limit, so smoothed-SII differences below that
value are not distinguishable from solver noise. The limit applies only
to the smoothed SII; as noted in the Methods, negative differences under
the complete and ANSI SII are genuine.

#strong[Table 3. Audiogram Family Sweep: Mean Floor Effect (SII at -10 dB
minus SII at 0 dB) at the 0.5-Sone Budget, by Audible Edge, with the
Anchor Penalty On and Off]

#figure(
  align(center)[#table(
    columns: 7,
    align: (left,left,left,left,left,left,left,),
    table.header([Audible edge], [Smoothed (on)], [Smoothed (off)],
      [Complete (on)], [Complete (off)], [ANSI (on)], [ANSI (off)],),
    table.hline(),
    [1000 Hz], [+0.036], [+0.053], [+0.017], [+0.022], [+0.050], [+0.094],
    [1500 Hz], [+0.009], [+0.023], [+0.001], [+0.005], [+0.012], [+0.040],
    [2000 Hz], [+0.005], [+0.012], [+0.003], [+0.006], [+0.007], [+0.019],
    [3000 Hz], [+0.000], [+0.001], [+0.000], [-0.000], [+0.001], [+0.002],
  )]
  , kind: table
  )

Table 3 gives the floor effect at the tightest budget, averaged over the
four slopes at each audible edge. With the anchor penalty on, the effect
at the 1000 Hz edge is 0.036 under the smoothed SII, 0.017 under the
complete SII, and 0.050 under the ANSI SII, exceeding the resolution
limit under all three. At the 1500 Hz edge it exceeds the limit under
the smoothed and ANSI SII (0.009 and 0.012) but not under the complete
SII (0.001). At the 2000 and 3000 Hz edges it is comparable to or below
the limit under every metric. The effect falls quickly as the budget loosens: at
1 sone only the 1000 Hz edge shows a benefit (0.011 smoothed, 0.001
complete, 0.017 ANSI), and at 2 and 3 sones none of the edges do.

Removing the anchor penalty increases the tightest-budget floor effect
at the 1000, 1500, and 2000 Hz edges, most under the ANSI SII (0.094 at
the 1000 Hz edge) and least under the complete SII (0.022). The ordering
across edges and metrics is largely unchanged, and at the 3000 Hz edge
the effect remains negligible. Only 7 of the 16 anchor-off pairs match
in loudness. In three pairs (edges of 1500 and 2000 Hz, slopes of 20
and 30 dB/octave) the -10 dB solution improves the smoothed SII by 0.011
to 0.014 while leaving 0.89 to 1.37 sones of the budget unspent. To
locate the source of this benefit, each -10 dB solution was rescored
with only its low-frequency gains (250--1000 Hz) or only its
high-frequency gains (2000--8000 Hz) applied to the 0 dB solution. The
low-frequency cut alone left the SII unchanged, whereas the
high-frequency gains alone reproduced the entire improvement, which
arose in the 4000--5800 Hz bands where audibility is limited by
threshold rather than by masking. The low-frequency cut therefore cost
no SII, because those near-normal bands remained fully audible, while
reducing loudness. That reduction was necessary: applied without the
low-frequency cut, the high-frequency gains would have exceeded the
loudness cap by 0.50 to 0.66 sones, so the 0 dB solution could not have
reached them. The same pattern held for A4 in the iso-loudness control,
where the high-frequency changes accounted for 0.0496 of the 0.0500
improvement and, applied alone, would have exceeded the cap by 1.87
sones. The floor effect is thus a loudness-budget effect: low-frequency
audibility that the SII does not need is traded for high-frequency gain
it does.

The budget left unspent in the three pairs has two sources. Adding 3 dB
at 2000 or 4000 Hz to the -10 dB solutions lowered the SII slightly
(by 0.0004 to 0.0022): those bands were already close to full
audibility, so further gain mainly increased the index's
level-distortion penalty. Adding 3 dB at 8000 Hz instead raised the SII
by 0.002 to 0.003 at a cost of 0.07 to 0.10 sones, so the unpenalized
optimizer stopped slightly short of the available benefit there, and
the floor effects for these pairs are slight underestimates.

In the anchor-on solutions, the reallocation of gain at matched
loudness can be read directly from the paired solutions. At the tightest
budget and the 1000 Hz edge, averaged over the two matched audiograms,
relaxing the floor lowers gain by 5.4 dB at 500 Hz and 2.1 dB at 1000
Hz and raises it by 8.1 dB at 2000 Hz and 5.0 dB at 4000 Hz; the change
at 8 kHz is small (-1.5 dB). Because these pairs are at matched
loudness, capacity drawn from the near-normal low frequencies is spent
in the 2--4 kHz region (Figure 2).

#figure(image("figures/Figure2_Mechanism_Spectral.png"),
  caption: [
    Change in prescribed insertion gain when the minimum-gain floor is
    relaxed from 0 dB to -10 dB, at a 0.5-sone loudness budget, by
    audible edge frequency, for the pairs matched in loudness (anchor
    penalty on). Grey lines show individual audiograms; the black line
    is their mean. Because the paired solutions are at matched loudness,
    loudness given up at one frequency is spent at another.
  ]
)

=== Formula Evaluation: Iso-Loudness Control
<formula-evaluation-iso-loudness-control>
To isolate the exact SII cost of preventing low-frequency attenuation,
an iso-loudness control experiment was conducted. The Open-NL
intelligibility maximizer was constrained to match the #emph[exact]
mathematical loudness output generated by NAL-NL2 for each profile at 65
dB SPL. It was then optimized twice: once with a strict 0 dB
low-frequency insertion gain floor, and once with a -10 dB floor.

As in the sweep, Open-NL optimized the smoothed SII, which approximates
the desensitization assumptions built into NAL-NL2, and each solution,
together with the NAL-NL2 prescription itself, was then scored with the
smoothed, complete, and ANSI SII. The primary goal is not to claim
algorithmic superiority over the clinical rationale, but to isolate the
efficiency cost of the 0 dB insertion floor within a controlled
mathematical space.

Table 4 details the difference in achieved smoothed SII when both the
formula and the optimizer are constrained to the same total sones. By
separating the #emph[optimizer effect] (the difference between Open-NL
at 0 dB and NAL-NL2) from the #emph[floor effect] (the difference
between Open-NL at -10 dB and 0 dB), the mechanism of loudness
crowding-out can be examined. Table 5 then gives the floor effect under
all three metrics, with the anchor penalty on and off.

#strong[Table 4. Iso-Loudness Control: Smoothed Desensitized SII
(Constrained to NAL-NL2 Loudness at 65 dB SPL; Anchor Penalty On)]

#figure(
  align(center)[#table(
    columns: (14.29%, 14.29%, 14.29%, 14.29%, 14.29%, 14.29%, 14.29%),
    align: (left,left,left,left,left,left,left,),
    table.header([Profile], [NAL-NL2 Loudness], [NAL-NL2 SII], [Open-NL
      (0 dB)], [Open-NL (-10 dB)], [Optimizer Effect], [Floor Effect],),
    table.hline(),
    [A1 (Mild)], [4.14
    sones], [0.734], [0.753], [0.786], [+0.019], [+0.033],
    [A2 (Reverse Slope)], [3.51
    sones], [0.769], [0.788], [0.799], [+0.019], [+0.011],
    [A3 (Moderate Sloping)], [3.63
    sones], [0.608], [0.605], [0.678], [-0.003], [+0.073],
    [A4 (Mod-Severe Precipitous)], [6.56
    sones], [0.670], [0.699], [0.719], [+0.028], [+0.020],
    [A5 (Profound Precipitous)], [5.50
    sones], [0.539], [0.586], [0.595], [+0.047], [+0.009],
    [A6 (Mixed)], [2.10
    sones], [0.717], [0.719], [0.719], [+0.003], [0.000],
    [A7 (Conductive)], [3.10
    sones], [0.971], [0.976], [0.976], [+0.005], [0.000],
  )]
  , kind: table
  )

#strong[Table 5. Iso-Loudness Control: Floor Effect under Three SII
Metrics, with the Anchor Penalty On and Off]

#figure(
  align(center)[#table(
    columns: 7,
    align: (left,left,left,left,left,left,left,),
    table.header([Profile], [Smoothed (on)], [Smoothed (off)],
      [Complete (on)], [Complete (off)], [ANSI (on)], [ANSI (off)],),
    table.hline(),
    [A1], [+0.033], [+0.053], [+0.008], [+0.014], [+0.037], [+0.064],
    [A2], [+0.011], [+0.012], [+0.005], [-0.000], [+0.015], [+0.017],
    [A3], [+0.073], [+0.066], [+0.045], [+0.035], [+0.094], [+0.085],
    [A4], [+0.020], [+0.050], [+0.002], [+0.006], [+0.024], [+0.085],
    [A5], [+0.009], [+0.037], [-0.002], [-0.003], [+0.006], [+0.086],
    [A6], [0.000], [---], [0.000], [---], [0.000], [---],
    [A7], [0.000], [---], [0.000], [---], [0.000], [---],
  )]
  , kind: table
  )

Under the smoothed SII with the anchor penalty on (Table 4), the floor
effect is largest for the moderate sloping profile A3 (+0.073),
followed by the mild profile A1 (+0.033), and is modest for the
precipitous profiles A4 (+0.020) and A5 (+0.009). For these profound
losses the improvement over NAL-NL2 instead comes mainly from the
optimizer effect: +0.028 for A4 and +0.047 for A5. Under the complete
SII the optimizer effect is +0.037 for A4 and +0.049 for A5, and under
the ANSI SII +0.055 and +0.105; the larger ANSI values partly reflect
that index crediting high-frequency gain NAL-NL2 withholds on purpose.

The floor effect depends strongly on how desensitization is scored
(Table 5). Under the complete SII, which the optimizer never targeted,
it remains clearly positive only for A3 (+0.045), is marginal for A1
(+0.008) and A2 (+0.005), and is negligible for the precipitous
profiles A4 (+0.002) and A5 (-0.002). Under the ANSI SII it is larger
for every sensorineural profile except A5.

Removing the anchor penalty sharpens this contrast. For A3 the floor
effect barely changes (0.066 smoothed, 0.035 complete, 0.085 ANSI), so
its benefit was never a penalty artifact. For the precipitous profiles
it grows substantially under the smoothed SII (A4 0.020 to 0.050; A5
0.009 to 0.037) and the ANSI SII (A4 0.024 to 0.085; A5 0.006 to
0.086), but stays at or below 0.006 under the complete SII. All five
anchor-off pairs match in loudness to within 0.001 sones, so these are
like-for-like comparisons. For the precipitous profiles, then, the
freed loudness is spent in exactly the frequency region the complete
correction treats as largely unusable: whether relaxing the floor helps
them depends on the desensitization assumption rather than on the
optimizer's regularization.

For the mixed and conductive profiles (A6, A7) the floor effect is
exactly zero and no frequency band receives negative gain, so the floor
never engages; these profiles were not rerun without the anchor. For
A2, the reverse-slope profile, the band receiving negative gain is 4000
Hz rather than the low frequencies---the only such case---which
naturally follows from the reverse-slope configuration. As a caveat,
for A1 the two anchor-on solutions differ in achieved loudness by 0.016
sones, so that profile alone is not exactly iso-loudness; every other
anchor-on profile matches to within 0.002 sones.

== Discussion
<discussion>
The $L_(c a p) - L_0$ budget bounds the achievable high-frequency gain
for precipitous losses as an independent constraint. For a profile like
A4 at 65 dB SPL, unamplified speech inherently generates 5.77 sones of
loudness. If evaluated against a strict 9.03 sone normal-hearing
ceiling, this unamplified energy consumes roughly 64% of the total
capacity before a single decibel of prescriptive gain is applied, though
this exact proportion is highly dependent on the chosen $L_(c a p)$.
While empirical rationales like NAL-NL2 correctly limit high-frequency
gain in these profiles due to physiological desensitization (leaving a
small fraction of the loudness budget unused), any clinical attempt to
aggressively restore high-frequency audibility beyond these conservative
limits (e.g., to maximize raw SII) will immediately collide with this
budget constraint. When clinical software enforces a minimum 0 dB
insertion gain floor, that residual third of the budget must cover the
entire high-frequency prescription, and it is nowhere near sufficient
for thresholds of 70 to 100 dB HL.

This constraint has a practical consequence. The penalized-optimal
solutions that benefit from relaxing the floor rely on negative
low-frequency insertion gain to free up loudness capacity. However,
digital gain reduction cannot bring the ear canal level below the
direct sound path in an open fitting: an open earset provides no
measurable insertion loss @kuk2009, and venting reduces amplified
low-frequency output rather than the unamplified direct sound
@stuart1999. To achieve true negative low-frequency insertion gain, a
clinician must use an unvented earmold, since venting largely removes
passive low-frequency attenuation @kuk2009. Even unvented molds
attenuate only modestly at the lowest frequencies, and they produce the
largest occlusion effects of any configuration @kuk2009@kiessling2005,
a particular burden for precipitous profiles with near-normal
low-frequency hearing.

Conversely, if the clinician opts for an open or vented fitting to avoid
occlusion (the standard of care for precipitous losses), the direct
sound path locks the low-frequency insertion gain floor at $gt.eq 0$ dB.
In the model, this forgoes whatever benefit relaxing the floor would
provide, reducing the achievable high-frequency gain before the
loudness cap is reached. This limitation is compounded by practical
electroacoustic constraints: larger vents also reduce the maximum gain
available before feedback @kuk2009, which independently limits the
high-frequency gain a device can deliver.

Crucially, this analysis does not suggest that clinicians should
actively pursue these theoretical SII maximums by occluding patients and
aggressively attenuating low frequencies. Due to physiological
desensitization and cochlear dead regions @cox2011@pepler2015, the
standard ANSI SII is known to overpredict actual behavioral speech
recognition in profound high-frequency losses. Applying massive
high-frequency gain often yields diminishing or even negative behavioral
returns for these patients. Rather, this index-level analysis serves to
map the boundaries of the acoustic parameter space. It demonstrates that
even if a clinician #emph[wished] to pursue higher high-frequency
gain---perhaps for a patient with exceptionally robust high-frequency
neural survival---they are constrained by the loudness budget
arithmetic of the open fitting.

Taken together, these analyses separate two explanations for the
difficulty of restoring high-frequency audibility in precipitous loss.
The loudness budget is a genuine constraint: unamplified speech in the
residual low frequencies consumes most of it before any gain is
prescribed. Relaxing the minimum-gain floor recovers part of that
budget, but whether the recovered capacity improves intelligibility
depends on desensitization. With the anchor penalty removed, the floor
effect for the precipitous profiles reached 0.037 to 0.086 when scored
with the smoothed or unmodified SII, yet was at most 0.006 under the
published Johnson and Dillon correction, because the freed capacity is
spent at frequencies that correction discounts. For the moderate
sloping profile the effect was positive under every metric and both
optimizer settings (0.035 to 0.094). In the four cases examined, the
benefit came from high-frequency gain funded by a low-frequency cut that
itself cost no intelligibility, confirming that the floor effect is a
loudness-budget effect. Because negative low-frequency insertion gain requires an
unvented fitting, the benefit does not justify sacrificing venting in
precipitous loss unless desensitization is mild. Strategies that
deliver high-frequency cues to regions of better hearing, such as
frequency lowering @simpson2009, remain the more plausible route; the
present analysis does not model them, and their benefit under a
loudness budget remains to be tested.

=== Limitations
<limitations>
Several methodological constraints should be noted when interpreting
these computational results. First, the specific-loudness engine
utilizes a monaural model; it does not explicitly capture the complex
dynamics of bilateral loudness summation in impaired listeners. Second,
the framework applies stationary loudness integration to a static
long-term average speech spectrum (LTASS). Real-world speech is highly
time-varying, and dynamic compression systems (WDRC) acting on
fluctuating speech may yield different instantaneous loudness profiles
@souza2002. Third, the analysis is fundamentally a theoretical,
index-level optimization; it lacks behavioral validation and does not
directly measure patient speech recognition outcomes. Fourth, although
the analysis evaluated the seven canonical profiles defined by
#cite(<johnson2011>, form: "prose") alongside a systematic sweep of
sixteen synthetic audiograms, the simulations were deliberately
constrained to synthetic thresholds and a single standard speech
spectrum. A broader corpus of real-world audiometric profiles and
variable speech inputs would still be required to generalize these
constraints across the diverse clinical population.

The floor analyses were also conducted only at 65 dB SPL with linear
gain. Figure 1 shows the budget tightening as input level rises, which
would favor a larger floor effect for loud speech; however, the SII's
level-distortion factor, which already offset additional 2--4 kHz gain
at 65 dB SPL, penalizes high presentation levels more strongly. The
direction of the effect at 50 and 80 dB SPL therefore cannot be inferred
from these results and would require a level-specific (compression)
analysis.

Similarly, the flat -10 dB minimum insertion gain floor utilized in
these simulations likely overstates achievable attenuation in the lowest
frequency bands. The reported floor effects should therefore be read as
likely optimistic estimates of the benefit of passive attenuation. A
frequency-shaped floor based on measured insertion loss would be more
realistic for future modeling, though measured attenuation values are
highly sensitive to clinical factors such as earmold seal, insertion
depth, and slit leak.

The optimizer's anchor penalty biases the reported floor effects in the
opposite direction, and its size was tested directly rather than
assumed. The anchor-off solutions bound what an essentially unpenalized
SII maximizer could achieve, but they are only weakly regularized and
should not be read as realistic prescriptions. The anchor-on and
anchor-off values together bracket the floor effect; the flat floor and
the anchor penalty push in opposite directions, so neither end of the
bracket is a one-sided overestimate. The anchor-off solutions are also
not exact optima: in the three sweep pairs that left budget unspent,
additional 8 kHz gain would still have raised the SII by a few
thousandths, so their floor effects are slightly understated.

Additionally, the loudness budget framework is limited in its
application to the mixed (A6, 30 dB conductive component) and conductive
(A7, 50 dB conductive component) profiles. Because unaided speech is
inaudible at conversational levels---only becoming audible at 80 dB SPL
with 0.17 and 0.28 sones---"budget above unaided" degenerates to an
absolute ceiling for these profiles. Evaluated against the 9.03-sone
ceiling at 65 dB SPL, the NAL-NL2-aided loudness for A6 and A7 (2.10 and
3.10 sones) uses a smaller fraction of the budget (0.23 and 0.34) than
for any sensorineural profile (A1--A5 range 0.39 to 0.73). Because the
iso-loudness control constrains Open-NL to that same loudness by
construction, its prescriptions use the identical fraction. This is
consistent with attenuation without recruitment, and the binding
constraint for mixed and conductive losses is therefore the air-bone-gap
anchoring rather than the loudness cap.

== Acknowledgments
<acknowledgments>
Generative AI tools were used in preparing this work. Gemini 3.1 Pro
(Google DeepMind) served as a programming and copyediting assistant,
refactoring R and C++ code and applying revisions to the manuscript
text. Claude (Anthropic; Opus 5.5 and Sonnet 5 models) was used to
audit the analysis code and its outputs, to write diagnostic and
analysis scripts in R, to draft portions of the revised text including
the abstract, and to locate and verify references against publisher
records. That audit identified the optimizer and scoring defects
described in the Methods and Results; the corrected analyses reported
here were run by the author. The author verified all AI-assisted code
through numerical checks against independent outputs, reviewed and
edited all AI-assisted text, and takes full responsibility for the
content, including the accuracy of all references.

== Data Availability
<data-availability>
The code used to execute the computational simulations, reproduce the
dataset, and generate the figures for this study is fully open-source
and available on GitHub (https://github.com/r-gregmisc/SII).

== References
<references>


#set bibliography(style: "jaaa.csl")

#bibliography("jaaa_refs.bib")
