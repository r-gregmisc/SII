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
#show table: set par(justify: false)
#show table: set text(hyphenate: false)
#show strong: set text(hyphenate: false)
#show figure.where(kind: image): set block(below: 2.5em)
#show figure.where(kind: image): it => {
  show figure.caption: cap => block(inset: (x: 0.5in))[
    #set align(left)
    #set par(first-line-indent: 0em)
    #set text(size: 11pt)
    #strong[#cap.supplement #context cap.counter.display(cap.numbering).]
    #cap.body
  ]
  it
}

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
  margin: (x: 1in, y: 1in),
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


#block[
#set par.line(numbering: none)
#align(center)[
  #par(justify: false)[#text(size: 1.3em, weight: "bold", hyphenate: false)[
    Does occluding the ear free loudness budget for high-frequency gain? A
    modeling study of standard audiograms
  ]]

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

#strong[Purpose:] To test whether unamplified speech in the residual low
frequencies consumes much of the loudness budget before gain is
prescribed, and whether freeing that budget with negative low-frequency
gain improves predicted intelligibility.

#strong[Research Design:] Computational modeling with the AUDMOD
specific-loudness model and the Speech Intelligibility Index (SII).

#strong[Study Sample:] Ten standard audiograms (Bisgaard et al.) and
sixteen synthetic audiograms.

#strong[Intervention:] Relaxing the minimum insertion-gain floor from 0
to −10 dB, which requires an unvented earmold.

#strong[Data Collection and Analysis:] The loudness budget was
decomposed at 50, 65, and 80 dB SPL. At 65 dB SPL, gains were optimized
at both floors in a sweep of audible edge, slope, and loudness budget
and in an iso-loudness control matched to NAL-NL2, maximizing either the
Johnson and Dillon desensitized SII or the uncorrected ANSI SII shown by
real-ear systems.

#strong[Results:] At 65 dB SPL, unamplified speech consumed 72% and 67%
of the normative ceiling for the two standard audiograms with
near-normal hearing through 2000 Hz, and 34% or less for the others. At
NAL-NL2 loudness, relaxing the floor did not change the desensitized SII
beyond search variability (about 0.008) for any standard audiogram, and
at normal-hearing loudness no solution used negative gain. A benefit
appeared only for synthetic audiograms with near-normal hearing through
1000 Hz at the tightest budget (0.011 to 0.016 across seeds);
there, fittings tuned to the ANSI SII gained 0.079 to 0.087 by that
metric but 0.013 to 0.014 under the correction.

#strong[Conclusions:] Near-normal low-frequency hearing consumes most of
the loudness budget before gain is applied. For representative
audiograms fitted at NAL-NL2 loudness, recovering that budget with
negative low-frequency gain adds no predicted intelligibility, although
the uncorrected SII displayed during verification can suggest otherwise.

#strong[Clinical Relevance Statement:] For listeners with near-normal
low-frequency hearing, open fittings cost no predicted intelligibility
at typical prescribed loudness. A rise in the real-ear SII from
occluding such a patient should not be read as real benefit, because the
displayed index omits desensitization.

#par(first-line-indent: 0em)[#strong[Key Words:] hearing aids; hearing
loss, high-frequency; loudness perception; speech intelligibility;
computer simulation]

#par(first-line-indent: 0em)[#strong[Abbreviations:] AMT = Auditory Modeling Toolbox; ANSI = American National
Standards Institute; HL = hearing level; LTASS = long-term average speech
spectrum; NAL-NL2 = National Acoustic Laboratories nonlinear
prescription, version 2; SII = Speech Intelligibility Index; SPL = sound
pressure level]

#pagebreak()

== Introduction
<introduction>
In the fitting of precipitous or profound high-frequency hearing loss,
achieving adequate high-frequency audibility without exceeding normative
loudness targets is a central clinical challenge. Historically, the
failure to restore high-frequency audibility has been attributed to the
inherent physiological damage of the auditory periphery---specifically,
hearing-loss desensitization and dead regions @moore2001, which sharply
limit the benefit of high-frequency audibility where thresholds exceed
about 55 dB HL @ching1998@hogan1998. Consequently, modern
prescriptive rationales like NAL-NL2 @keidser2011 deliberately limit
high-frequency gain for profound thresholds to avoid prescribing "wasted"
amplification.

Desensitization limits the usefulness of high-frequency gain; loudness
may limit how much of it can be provided. Unamplified speech produces a
baseline loudness ($L_0$) through residual hearing. If a patient's target
loudness is held to a normative ceiling ($L_(c a p)$), the loudness left
to "purchase" high-frequency audibility through gain is
$L_(c a p) - L_0$. Because this budget is set by the audiogram and the
speech spectrum rather than by the fitting rationale, it could limit
high-frequency gain under any loudness-based rationale (e.g., NAL-NL2)
and under any attempt to maximize intelligibility.

The ANSI S3.5-1997 Speech Intelligibility Index (SII) @ansi1997 assigns
most of its importance weight to the 1--4 kHz bands and little below 500
Hz, so an algorithm that maximizes it under a strict loudness budget
will tend to attenuate low-frequency audibility to fund high-frequency
gain. Relaxing a constraint cannot lower the optimum of an optimization
problem, so the clinical relevance lies in quantifying the
magnitude of this trade-off for realistic audiometric profiles, and in
whether it survives when the index is corrected for desensitization.
#cite(<ching2001>, form: "prose") demonstrated that fitting options
should be compared at equal loudness and with an index corrected for
desensitization, the principle on which NAL-NL1 and NAL-NL2 were
derived. The present study applies that principle to a question those
comparisons did not address: whether the loudness of unamplified speech
in near-normal low frequencies, which a 0 dB minimum gain cannot reduce,
limits the budget left for high-frequency gain, and whether recovering
it with negative low-frequency gain, which requires an unvented fitting,
improves predicted intelligibility. It also asks whether any such
limit is peculiar to precipitous losses or is a general property of
near-normal low-frequency hearing.

== Methods
<methods>
=== Study Design
<study-design>
The study comprised two analyses. The first, a loudness budget
decomposition, required no gain optimization: it compared the loudness
of unamplified speech with a normative ceiling at 50, 65, and 80 dB SPL
to show how much of the budget residual hearing consumes and how that
proportion changes with input level. The second, which tested whether
relaxing the minimum insertion-gain floor improves intelligibility
within that budget (the floor effect: the SII with a −10 dB floor minus
the SII with a 0 dB floor), required optimizing gains and was performed at 65 dB
SPL only, the level of average conversational speech. The audiogram
family sweep and the iso-loudness control therefore describe behavior at
65 dB SPL; behavior at other levels is considered in the Limitations.

=== The AUDMOD Specific-Loudness Model
<the-audmod-specific-loudness-model>
Loudness was computed with the AUDMOD specific-loudness model
@bramslow1993@bramslow2004. AUDMOD, implemented in the Auditory Modeling Toolbox @majdak2022, takes
the audiogram directly as its description of hearing loss. The model of
#cite(<chen2011>, form: "prose"), also in that toolbox, likewise
addresses cochlear hearing loss, but it requires the loss at each
frequency to be divided between outer and inner hair cell components,
which an audiogram does not specify.
This model converts acoustic excitation patterns into specific
loudness (sones/ERB) and integrates them across the frequency spectrum
to predict overall broadband loudness. Passing the unamplified long-term
average speech spectrum (LTASS) through it gives the baseline loudness
$L_0$ produced by residual hearing. Throughout this work the LTASS is the
ANSI S3.5-1997 standard speech spectrum for normal vocal effort
@ansi1997, scaled to the evaluation level; the SII uses it in its
critical bands, and the loudness model receives it sampled at the six
octave frequencies and interpolated (Supplementary Section S2).

=== Study Sample and Audiometric Profiles
<study-sample-and-audiometric-profiles>
The study used the ten standard audiograms of
#cite(<bisgaard2010>, form: "prose"), proposed for the IEC 60118-15
hearing aid measurement procedure and derived from a clinical database
of measured audiograms: seven flat and moderately sloping configurations
(N1--N7, very mild to profound) and three steep sloping configurations
(S1--S3), all sensorineural (Table 1). Thresholds at the octave
frequencies from 250 to 4000 Hz were taken from their published tables;
because those tables end at 6000 Hz, the 8000 Hz threshold was set equal
to the 6000 Hz value. Thresholds are in dB HL for supra-aural earphones,
the reference assumed by the AUDMOD loudness model; the SII uses the
same values through the reference internal noise of ANSI S3.5-1997.

#block(breakable: false, width: 100%)[
#strong[Table 1. Standard Audiograms (dB HL)]

#figure(
  align(center)[#table(
    columns: 8,
    align: (left,left,right,right,right,right,right,right,),
    table.header([Profile], [Category], [250], [500], [1000], [2000], [4000], [8000],),
    table.hline(),
    [N1], [Very mild], [10], [10], [10], [15], [30], [40],
    [N2], [Mild], [20], [20], [25], [35], [45], [50],
    [N3], [Moderate], [35], [35], [40], [50], [60], [65],
    [N4], [Moderate/severe], [55], [55], [55], [65], [75], [80],
    [N5], [Severe], [65], [70], [75], [80], [80], [80],
    [N6], [Severe], [75], [80], [85], [90], [100], [100],
    [N7], [Profound], [90], [95], [105], [105], [105], [105],
    [S1], [Very mild, steep], [10], [10], [10], [15], [55], [70],
    [S2], [Mild, steep], [20], [20], [25], [55], [95], [95],
    [S3], [Mod./severe, steep], [30], [35], [60], [75], [80], [85],
  )]
  , kind: table
  )

#par(first-line-indent: 0em)[#text(size: 10pt)[#emph[Note:] From
#cite(<bisgaard2010>, form: "prose"), Tables 2 and 4. The 8000 Hz value
repeats their 6000 Hz value.]]
]

=== The Open-NL Computational Instrument
<the-open-nl-computational-instrument>
Gains were optimized with Open-NL, an open-source computational testbed
that couples a multi-start Nelder-Mead SII optimizer to the
specific-loudness engine. Open-NL serves here as an analytical
instrument, not a clinical prescription. Its wide dynamic range
compression was bypassed, so the optimizer solved for linear insertion
gain at 65 dB SPL.

The optimizer was subject to a minimum insertion-gain floor in every
band. A negative floor represents the
passive insertion loss of an occluding earmold (the real-ear occluded
response minus the real-ear unaided response). Measured insertion loss
is frequency dependent and smallest at the lowest frequencies, even for
unvented molds @kuk2009, so the flat −10 dB floor used here is an
idealization that is likely optimistic in the lowest bands. For these
audiograms the floor binds, if at all, only at the low frequencies.

Comparison targets were generated with the NAL-NL2 software (v2.0, dll
v2.15, Clinician Edition) @keidser2011 from the same six thresholds in
each ear, for an adult male experienced bilateral user of a non-tonal
language, with dual (adaptive) compression speed, 18 channels, the
default compression threshold, supra-aural earphones as the threshold
transducer, and an occluded earmold with \#13 tubing. Male was chosen to
match Open-NL's heuristic prescription, and the occluded coupling keeps
the targets free of venting effects. Real-ear insertion-gain targets
for speech at 65 dB SPL were used. The bilateral setting applies a binaural loudness
correction that lowers prescribed gain, whereas the loudness model used
here is monaural. This mismatch lowers NAL-NL2's predicted loudness, and
therefore the loudness cap of the iso-loudness control, by an amount that
was not quantified.

=== Loudness Model Implementation and Verification
<c-instrument-validation>
Open-NL evaluates tens of thousands of candidate gain curves per
optimization, and calling the AUDMOD implementation in AMT 1.6.0
(`bramslow2004`) @majdak2022 through Octave for each evaluation was
prohibitively slow. The model was therefore ported to C++ using `Rcpp`.
Across 23 test cases, the port matched the AMT implementation at every
processing stage to within a maximum relative discrepancy of
$5.71 times 10^(- 15)$; this establishes that the port reproduces
AUDMOD, not that AUDMOD itself is accurate. Reference-free checks
confirmed that loudness is zero below threshold and that recruitment is
present and ordered by threshold, and in normal hearing loudness grew by
a factor of 1.75 to 1.91 per 10 dB above 40 phons, mildly compressive
relative to the textbook doubling. The absolute sone scale is inherited
from AUDMOD and has not been independently verified against loudness
judgments. Checks of the input path and further details are given in
Supplementary Section S1.

=== Intelligibility Metrics
<intelligibility-metrics>
Two versions of the SII were used. The #emph[ANSI SII] is the index
as standardized @ansi1997, with no correction for desensitization. The
#emph[desensitized SII] reduces
each band's audibility $K_i$ by a desensitization factor that falls as
the band's sensorineural threshold $T_i$ (dB HL) rises,
$m_i = 1 \/ (1 + e^(0.075 (T_i - 66)))$, using the correction published by
#cite(<johnson2011>, form: "prose", supplement: [p. 446]), a power mean:
$ K'_i = (K_i^(p_i) + m_i^(p_i))^(1 \/ p_i), quad p_i = T_i \/ 8 - 15. $
Because $p_i$ is strongly negative at mild to moderate thresholds
($p_i = −10$ at 40 dB HL), this behaves approximately as
$min(K_i, m_i)$ there: once a band's audibility reaches $m_i$, further
audibility earns little credit. At severe to profound thresholds $p_i$
approaches $−1$ and the correction is more gradual. The desensitized
SII is the optimizer's objective throughout, except for a second set of
fittings, described with the iso-loudness control, that maximize the
ANSI SII instead. The ANSI SII, which real-ear measurement
systems typically display, is reported for the same solutions.

=== Optimization Procedure
<optimization-procedure>
Gains were optimized by multi-start Nelder-Mead simplex search over six
free parameters: a gain shift at each octave frequency from 250 to 8000
Hz, added to Open-NL's built-in rule-based heuristic prescription and interpolated
logarithmically across the 21 analysis bands. The heuristic used the
package defaults: a fully occluded coupling with no vent correction, the
severe-loss booster disabled, and no demographic adjustments.

The solutions are penalized-optimal rather than strictly SII-optimal:
the optimizer maximizes the desensitized SII, multiplied by 100, minus a set of
penalty terms, so that one objective point corresponds to 0.01 SII.
Three penalties shape the solutions reported here. The anchor penalty
subtracts 0.1 point for every decibel by which the gain at an octave
frequency is shifted, in either direction, from the heuristic
prescription, pulling solutions toward it. The roughness penalty
subtracts 0.001 point per squared decibel of difference between the
gains at adjacent octave frequencies, discouraging jagged responses. The
loudness penalty subtracts 2000 points per sone by which aided loudness
exceeds the cap, which in practice makes the cap a hard ceiling. The
remaining penalties are safeguards that were inactive or rarely engaged
here (Supplementary Section S2).

Each optimization used 20 random restarts unless stated otherwise, and
the solver retains the solution with the best penalized objective, which
need not have the highest SII. The random seed is fixed by the audiogram
and level, so a 40-restart run repeats the first 20 restarts and can
only improve on the 20-restart objective. Because repeated runs are
therefore identical, search variability was estimated separately by
repeating key comparisons with five further seeds (Supplementary
Section S4).

The anchor penalty keeps solutions close to a plausible prescription
shape, but it also works against the manipulation under test. Because
the heuristic is floored at 0 dB before shifts are applied, any gain
below 0 dB is a penalized shift: driving two low-frequency bands to the
−10 dB floor costs 2 × 10 dB × 0.1 = 2 points, or 0.02 SII, the same
order as the floor effects of interest. With the anchor penalty on, the
floor effect is therefore biased downward. The tightest-budget sweep and
the iso-loudness control were repeated with the anchor weight set to
zero (20 restarts). These anchor-off solutions are constrained only by
the loudness cap, the floor, and the weak roughness penalty; they
indicate what an essentially unrestricted SII maximizer could achieve
rather than realistic prescriptions. Anchor-on and anchor-off results
are reported together as a bracket.

== Results
<results>
=== Loudness Budget Decomposition
<loudness-budget-decomposition>
The unamplified loudness of speech ($L_0$) was computed at 50, 65, and
80 dB SPL and compared with a normative ceiling ($L_(c a p)$), defined as
the loudness of unaided speech for a 0 dB HL listener at the same level:
3.16, 9.03, and 22.39 sones, respectively. The ceiling is the same for
every listener. The difference, $L_(c a p) - L_0$, is the model-predicted
budget available to "purchase" high-frequency audibility through gain
before aided loudness exceeds that of normal hearing.

An empirical anchor for this ceiling would be preferable, and NAL-NL2
was examined as a candidate. It does not provide one:
NAL-NL2-prescribed aided loudness for 65 dB SPL speech, as a fraction of
the ceiling, ranges from 0.07 to 0.78 across nine of the standard
audiograms (0.78 for N1, 0.74 for S1, 0.54 for N2, 0.49 for S2, and 0.26
or less for the rest) and is zero for N7, because NAL-NL2 optimizes loudness against
its own criteria rather than a fixed proportion of normal-hearing
loudness.

$L_(c a p)$ is therefore a modeling assumption, not a measured quantity,
and target loudness varies across patients and rationales. The floor
analyses below accordingly do not rely on it alone: the audiogram family
sweep sets each budget relative to the listener's own unaided loudness,
at four values, and the iso-loudness control uses the loudness NAL-NL2
prescribes.

#block(breakable: false, width: 100%)[
#strong[Table 2. Loudness Budget Decomposition: Unamplified Loudness
($L_0$, Sones) and Fraction of the Normative Ceiling Consumed, at 50, 65,
and 80 dB SPL]

#figure(
  align(center)[#table(
    columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right, right, right, right),
    table.header(
      [],
      table.cell(colspan: 3, align: center)[$L_0$ (sones)],
      table.cell(colspan: 3, align: center)[Ceiling consumed (%)],
      table.hline(start: 1, end: 4, stroke: 0.5pt),
      table.hline(start: 4, end: 7, stroke: 0.5pt),
      [Profile], [50], [65], [80], [50], [65], [80],
    ),
    table.hline(),
    [N1], [1.76], [6.50], [17.73], [55.9], [72.0], [79.2],
    [N2], [0.44], [3.09], [10.43], [13.8], [34.2], [46.6],
    [N3], [0.00], [0.60], [4.11], [0.0], [6.6], [18.4],
    [N4], [0.00], [0.00], [1.16], [0.0], [0.0], [5.2],
    [N5], [0.00], [0.00], [0.00], [0.0], [0.0], [0.0],
    [N6], [0.00], [0.00], [0.00], [0.0], [0.0], [0.0],
    [N7], [0.00], [0.00], [0.00], [0.0], [0.0], [0.0],
    [S1], [1.71], [6.06], [16.29], [54.3], [67.1], [72.8],
    [S2], [0.43], [2.71], [8.63], [13.6], [30.0], [38.6],
    [S3], [0.00], [0.42], [2.61], [0.0], [4.7], [11.7],
  )]
  , kind: table
  )

#par(first-line-indent: 0em)[#text(size: 10pt)[#emph[Note:] The ceiling
$L_(c a p)$ is 3.16, 9.03, and 22.39 sones at 50, 65, and 80 dB SPL.]]
]


The fraction consumed (Table 2) depends mainly on how close the low-frequency
thresholds are to normal. The two audiograms with thresholds of 10 to 15
dB HL through 2000 Hz, N1 and S1, consume 72.0% and 67.1% of the
ceiling at 65 dB SPL, although S1 has a steep high-frequency loss and N1
only a mild one. With low-frequency thresholds of 20 to 25 dB HL, as in
N2 and S2, the fraction falls to 34.2% and 30.0%, even though S2 has the
greatest overall high-frequency slope in the set. From N3 and S3 upward, unamplified speech
consumes 6.6% or less, and for N4 to N7 it is inaudible to the model at
65 dB SPL. The fraction consumed rises with input level wherever speech
is audible (Figure 1), so the constraint tightens as speech gets louder:
N1 consumes 55.9%, 72.0%, and 79.2% of the ceiling at 50, 65, and 80 dB
SPL. If a
prescription enforces a minimum insertion gain of 0 dB, these $L_0$
values cannot be reduced, and only the remainder of the ceiling is
available for high-frequency gain. Whether relaxing the floor to recover
part of $L_0$ improves intelligibility was tested at 65 dB SPL in the
analyses that follow.

=== The Audiogram Family Sweep
<the-audiogram-family-sweep>
Sixteen synthetic audiograms crossed four audible edge frequencies
(1000, 1500, 2000, 3000 Hz) with four high-frequency slopes (20, 30, 40,
50 dB/octave): thresholds were 10 dB HL up to the audible edge and rose
above it at the stated slope, to a maximum of 110 dB HL. Each was
evaluated at four loudness budgets and two minimum-gain floors (0 and
−10 dB), giving 64 paired cells. Unlike the fixed ceiling of the budget
decomposition, each budget was set relative to the listener's own
unaided loudness, at 0.5, 1, 2, or 3 sones above $L_0$. For scale,
NAL-NL2 at 65 dB SPL spends 0.54 to 2.04 sones above $L_0$ for the
standard audiograms (Tables 2 and 4; N7 excepted). Each floor was
optimized with 20 random restarts, and each solution was scored with the
desensitized and ANSI SII.

At the tightest budget the loudness cap should bind at both floors.
Fifteen of the 16 pairs matched in achieved loudness to within 0.001
sones; the sixteenth matched after re-optimization with 40 restarts,
and its 40-restart solutions are used throughout. Overall, 50 of the 64
paired cells match (16, 11, 10, and 13 of 16 at budgets of 0.5, 1, 2,
and 3 sones).

Because the 0 dB feasible set lies within the −10 dB set, relaxing the
floor cannot lower the penalized objective at a true optimum, but it can
lower the SII when the wider search space lets the solution trade a
little SII for a smaller penalty. Across the 50 matched pairs, 23
desensitized-SII floor effects are negative (median magnitude 0.0009,
maximum 0.0084). In all but five of the 50 the penalized objective was
the same or higher at −10 dB, and in those five it was lower by at most
0.04 points (0.0004 SII), so the search itself converged. Desensitized-SII floor effects no larger in magnitude than the largest
negative value (0.0084, hereafter about 0.008) are therefore treated as
indistinguishable from zero; this is the resolution limit. An
independent estimate agreed: when the floor comparison was repeated with
six random seeds for the four 1000 Hz edge audiograms and for N1, N2, S1,
and S2 at NAL-NL2 loudness, the pooled within-case standard deviation of
the floor effect was 0.0037 (2 SD = 0.0075; Supplementary Section S4).

#block(breakable: false, width: 100%)[
#strong[Table 3. Audiogram Family Sweep: Mean Floor Effect (SII at −10 dB
minus SII at 0 dB) at the 0.5-Sone Budget, by Audible Edge, with the
Anchor Penalty On and Off]

#figure(
  align(center)[#table(
    columns: 5,
    align: (left,left,left,left,left,),
    table.header([Audible edge], [Desensitized (on)], [Desensitized (off)],
      [ANSI (on)], [ANSI (off)],),
    table.hline(),
    [1000 Hz], [+0.014], [+0.015], [+0.039], [+0.047],
    [1500 Hz], [0.000], [+0.004], [+0.004], [+0.017],
    [2000 Hz], [+0.002], [+0.002], [+0.005], [+0.010],
    [3000 Hz], [−0.003], [+0.001], [−0.003], [+0.004],
  )]
  , kind: table
  )

#par(first-line-indent: 0em)[#text(size: 10pt)[#emph[Note:] On and off
indicate whether the optimizer's anchor penalty was applied (see
Optimization Procedure). Each value is the mean over the four slopes.
All 16 anchor-on pairs matched in loudness; 8 of the 16 anchor-off pairs
did.]]
]

Table 3 gives the floor effect at the tightest budget, averaged over the
four slopes at each audible edge. With the anchor penalty on, the effect
at the 1000 Hz edge is 0.014 under the desensitized SII and 0.039 under the
ANSI SII. At the 1500, 2000, and 3000 Hz edges it is within the
resolution limit under the desensitized SII and at most 0.005 under the ANSI
SII. The benefit at the 1000 Hz edge does not depend on the random
starts: across six seeds, all 24 floor effects for those four audiograms
were positive (0.005 to 0.020; audiogram means 0.011 to 0.016). The
effect disappears as the budget loosens: at 1, 2, and 3 sones no edge
shows a mean benefit above 0.003 under either metric.

Removing the anchor penalty leaves the desensitized-SII floor effect nearly
unchanged (0.015 at the 1000 Hz edge and at most 0.004 elsewhere) but
raises it under the ANSI SII (0.047 at the 1000 Hz edge and 0.017 at
1500 Hz). Only 8 of the 16 anchor-off pairs match in loudness. In four
(edges of 1500 to 3000 Hz, slopes of 20 to 40 dB/octave), the −10 dB
solution leaves 0.83 to 1.38 sones of the budget unspent while changing
the desensitized SII by at most 0.005.

To locate the source of the benefit at the 1000 Hz edge, each −10 dB
solution (anchor on) was rescored with only its low-frequency
(250--1000 Hz) or only its high-frequency (2000--8000 Hz) gains applied
to the 0 dB solution. The low-frequency cut alone changed the desensitized
SII by at most 0.0005, because those near-normal bands remained fully
audible, whereas the high-frequency gains alone reproduced the entire
improvement, in the bands centered at 1600 to 3400 Hz, where audibility
is limited by threshold rather than by masking. Applied without the
low-frequency cut, however, those high-frequency gains would have
exceeded the loudness cap by 0.44 to 0.72 sones, so the 0 dB solution
could not have reached them. The floor effect is thus a loudness-budget effect:
low-frequency audibility the SII does not need is traded for audibility
at higher frequencies that it does.

In the anchor-on solutions, the reallocation of gain at matched
loudness can be read directly from the paired solutions. At the tightest
budget and the 1000 Hz edge, averaged over the four audiograms, relaxing
the floor lowers gain by 4.0 dB at 500 Hz and raises it by 7.2 dB at
2000 Hz; gain at 8000 Hz also falls, by 5.2 dB, where the desensitization
correction credits little audibility at these thresholds. Because these
pairs are at matched loudness, capacity drawn from the near-normal low
frequencies and from 8000 Hz is spent around 2000 Hz (Figure 2).


=== Iso-Loudness Control
<formula-evaluation-iso-loudness-control>
To isolate the SII cost of preventing low-frequency attenuation at a
clinically realistic loudness, Open-NL was constrained to the loudness
of the NAL-NL2 prescription for each profile at 65 dB SPL and optimized
twice, with 0 dB and −10 dB floors. As in the sweep, it optimized the
desensitized SII, and each solution, together with the NAL-NL2 prescription,
was scored with both metrics. The control was repeated with the
optimizer maximizing the ANSI SII, to represent a fitting tuned to the
index that real-ear systems display. The aim is not to compare Open-NL
with the clinical rationale but to isolate the cost of the 0 dB floor at
matched loudness. Table 4 separates the #emph[optimizer effect] (Open-NL
at 0 dB minus NAL-NL2) from the #emph[floor effect] (Open-NL at −10 dB
minus 0 dB) under the desensitized SII; Table 5 gives the floor effect under
both metrics, with the anchor penalty on and off.

#block(breakable: false, width: 100%)[
#strong[Table 4. Iso-Loudness Control: Desensitized SII
(Constrained to NAL-NL2 Loudness at 65 dB SPL; Anchor Penalty On)]

#figure(
  align(center)[#table(
    columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right, right, right, right),
    table.header([Profile], [NAL-NL2 loudness (sones)], [NAL-NL2 SII],
      [Open-NL (0 dB)], [Open-NL (−10 dB)], [Optimizer effect],
      [Floor effect],),
    table.hline(),
    [N1], [7.04], [0.883], [0.900], [0.899], [+0.017], [−0.001],
    [N2], [4.84], [0.809], [0.825], [0.823], [+0.016], [−0.002],
    [N3], [2.32], [0.643], [0.648], [0.645], [+0.005], [−0.003],
    [N4], [2.04], [0.428], [0.424], [0.424], [−0.005], [0.000],
    [N5], [1.57], [0.243], [0.233], [0.233], [−0.010], [0.000],
    [N6], [0.63], [0.119], [0.114], [0.114], [−0.005], [0.000],
    [N7], [0.00], [0.023], [0.016], [0.016], [−0.007], [0.000],
    [S1], [6.64], [0.792], [0.814], [0.810], [+0.022], [−0.004],
    [S2], [4.42], [0.558], [0.594], [0.595], [+0.036], [+0.001],
    [S3], [1.42], [0.418], [0.421], [0.424], [+0.003], [+0.003],
  )]
  , kind: table
  )
]

#block(breakable: false, width: 100%)[
#strong[Table 5. Iso-Loudness Control: Floor Effect under the Desensitized
and ANSI SII, with the Anchor Penalty On and Off]

#figure(
  align(center)[#table(
    columns: 5,
    align: (left,left,left,left,left,),
    table.header([Profile], [Desensitized (on)], [Desensitized (off)],
      [ANSI (on)], [ANSI (off)],),
    table.hline(),
    [N1], [−0.001], [+0.004], [0.000], [+0.009],
    [N2], [−0.002], [+0.001], [−0.004], [+0.005],
    [N3], [−0.003], [−0.005], [−0.003], [0.000],
    [N4], [0.000], [0.000], [0.000], [0.000],
    [N5], [0.000], [0.000], [0.000], [0.000],
    [N6], [0.000], [0.000], [0.000], [0.000],
    [N7], [0.000], [0.000], [0.000], [0.000],
    [S1], [−0.004], [0.000], [−0.002], [+0.012],
    [S2], [+0.001], [0.000], [0.000], [0.000],
    [S3], [+0.003], [+0.001], [+0.002], [+0.002],
  )]
  , kind: table
  )

#par(first-line-indent: 0em)[#text(size: 10pt)[#emph[Note:] On and off
indicate whether the optimizer's anchor penalty was applied (see
Optimization Procedure). Solutions were optimized on the desensitized SII.
Only N1 and S1 received negative gain, and N2 also without the anchor
penalty; elsewhere the floor did not engage, and nonzero values reflect
search variability.]]
]

With the anchor penalty on (Table 4), relaxing the floor changed the
desensitized SII by −0.004 to +0.003 for every audiogram, within the
resolution limit. Only N1 and S1, the two audiograms with near-normal
hearing through 2000 Hz, received any negative gain (at 500 and 1000
Hz), and for both the effect was slightly negative (−0.001 and −0.004);
for N4 to N7 the floor never engaged. Without the anchor penalty the
range was −0.005 to +0.004 (Table 5), and the ANSI SII of the same
solutions changed by at most 0.012 (S1). At the loudness NAL-NL2
prescribes, none of the standard audiograms gained predicted
intelligibility from relaxing the floor. For N4 to N7 unaided speech is
inaudible to the model, so the floor could not matter; the informative
cases are the four with audible low-frequency speech, N1, N2, S1, and S2.
Across six random seeds their mean floor effects were −0.003 to +0.002.
Single runs for N1 and N2 varied more (−0.010 to +0.010; SD 0.006 to
0.007), so an individual value for these two is uncertain to about
±0.01, but no mean approached the benefit at the 1000 Hz edge.

The reasons differ across the set. N1 and S1 have the tightest budgets,
NAL-NL2 spending only 0.54 and 0.58 sones above their unaided loudness,
but their thresholds stay near normal through 2000 Hz, like the sweep
audiograms with edges of 2000 Hz and above, for which the floor effect
was also within the resolution limit (Table 3). N2 and S2 consume less
of the ceiling, and NAL-NL2 leaves them about 1.7 sones of budget; from
N3 and S3 upward there is almost no unaided loudness to recover. The
optimizer effect was positive for near-normal or mild low-frequency loss
(up to +0.036, S2) and slightly negative for N4 to N7 (−0.005 to
−0.010), where the anchored search fell short of NAL-NL2; this does not
affect the floor effect.

Fittings tuned to the ANSI SII behaved the same way. By that metric
relaxing the floor gained at most 0.011 with the anchor penalty and 0.027
without it (S2), but under the desensitization correction the same solutions
changed by −0.005 to +0.008 (Supplementary Section S2).

For the fittings optimized on the desensitized SII (Tables 4 and 5), all pairs
matched in loudness to within 0.008 sones with the anchor penalty.
Without it, all but N2 matched to within 0.012 sones; N2's −10 dB
solution left 0.66 sones of the budget unspent.

=== Floor Effect at the Normative Ceiling
<floor-effect-at-the-normative-ceiling>
The floor analyses above constrain loudness to NAL-NL2's prescription or
to small increments above unaided loudness, never to $L_(c a p)$ itself.
To test the comparison at the normative ceiling, the optimization for
N1, N2, S1, and S2 was repeated with the cap set to $L_(c a p)$ (9.03
sones), a budget of 2.5 to 6.3 sones above $L_0$ rather than the 0.5 to
1.8 sones NAL-NL2 uses. With or without the anchor penalty, no solution
gave any band negative gain, so the floor never engaged; differences
between floors reflected only search variability (largest 0.012, N2).
Only N1 with the anchor penalty spent the whole budget; the other
solutions stopped 0.1 to 3.8 sones short of it. The extra loudness raised
the desensitized SII above that of NAL-NL2 by 0.007 to 0.031 (anchor on).
When loudness is this loosely constrained, the optimizer has no reason
to cut low-frequency gain (Supplementary Section S4).

== Discussion
<discussion>
How much of the normal-hearing loudness ceiling remains for
high-frequency gain is set largely by the low frequencies. For N1 and
S1, the standard audiograms with near-normal hearing through 2000 Hz,
unamplified speech at 65 dB SPL generates 6.50 and 6.06 sones, 72% and
67% of the 9.03-sone normal-hearing ceiling, before any gain is applied,
although the exact proportion depends on the chosen $L_(c a p)$. With a
minimum insertion gain of 0 dB, the remaining quarter to third of the
budget must cover the entire high-frequency prescription. The steepness
of the high-frequency loss matters much less: S2, with the greatest
overall high-frequency slope in the set, consumes 30% because its low-frequency thresholds are 20 to
25 dB HL.

This has a practical consequence. Any benefit from relaxing the floor
relies on negative low-frequency insertion gain, but
digital gain reduction cannot lower the ear-canal level below the direct
sound path in an open fitting: an open earset provides no measurable
insertion loss @kuk2009, and venting reduces amplified low-frequency
output rather than the unamplified direct sound @stuart1999. True
negative low-frequency insertion gain therefore requires an unvented
earmold @kuk2009. Even unvented molds attenuate only modestly at the
lowest frequencies, and they produce the largest occlusion effects of
any configuration @kuk2009@kiessling2005, a particular burden for
listeners with near-normal low-frequency hearing.

Conversely, an open or vented fitting, the standard of care when
low-frequency hearing is near normal, limits the low-frequency insertion
gain to about 0 dB or more. In the model this cost no predicted
intelligibility for the standard audiograms fitted at NAL-NL2 loudness,
although larger vents also reduce the gain available before feedback
@kuk2009, independently limiting high-frequency gain.

This analysis does not suggest that clinicians pursue these SII maxima
by occluding patients and attenuating low frequencies. Because of
desensitization @ching1998@hogan1998, the ANSI SII overpredicts speech
recognition in severe high-frequency loss, although high-frequency
amplification is rarely harmful: listeners with high-frequency cochlear
dead regions still benefited from it on average, if less in noise
@cox2011@pepler2015.

Which version of the SII is consulted also matters clinically.
Real-ear verification systems report the ANSI SII without any
correction for hearing-loss desensitization @audioscan2026, and aided
SII values are used to judge whether a fitting is acceptable
@audioscan2026@scollie2018@wiseman2023. Where relaxing the floor helped
at all, the uncorrected index overstated the benefit several-fold. At
the 1000 Hz audible edge and the tightest budget, fittings tuned to the
ANSI SII gained 0.079 to 0.087 from relaxing the floor by that metric
but 0.013 to 0.014 under the desensitization correction, no more than fittings
tuned to the corrected index itself (0.014 to 0.015); at the 1500 Hz
edge a displayed gain of 0.027 to 0.038 corresponded to 0.004 to 0.005
(Supplementary Section S2). For the standard audiograms, fittings tuned
to the ANSI SII showed up to 0.027 by that metric and no change beyond
the resolution limit under the correction. #cite(<ching2001>, form: "prose") cautioned that simple audibility
indices and visual displays of audibility, which ignore desensitization,
can lead to erroneous judgments about the relative benefits of hearing
aid options, and
fitting to maximize the uncorrected articulation index lowered scores
for listeners with sloping high-frequency loss and near-normal
low-frequency hearing @rankovic1991. A rise in the displayed SII from
occluding such a patient should therefore not be taken as evidence of
benefit, and the results support continued venting to manage occlusion
rather than pursuit of ANSI SII improvements.

Taken together, these analyses separate two explanations for the
difficulty of restoring high-frequency audibility when low-frequency
hearing is near normal. Unamplified speech in near-normal low
frequencies does consume most of the normal-hearing loudness ceiling
before any gain is prescribed. But recovering part of it by relaxing the
minimum-gain floor bought no predicted intelligibility under the
desensitized index for representative audiograms at the loudness
NAL-NL2 prescribes, with or without the anchor penalty, and at the full
normal-hearing ceiling no solution cut low-frequency gain at all. A
benefit required a combination absent from the standard set: near-normal
hearing through 1000 Hz, a steep loss immediately above it, and a tight
budget. Even there it was small under the published correction (0.011
to 0.016), and it came from gain above the low frequencies that the
loudness cap could not otherwise accommodate, funded by a low-frequency
cut. Because negative low-frequency insertion gain requires an unvented
fitting, these results give no reason to sacrifice venting. Strategies
that deliver high-frequency cues to regions of better hearing, such as
frequency lowering @simpson2009, remain the more plausible route; the
present analysis does not model them, and their benefit under a loudness
budget remains to be tested.

=== Limitations
<limitations>
Several constraints apply to these computational results. The loudness
model is monaural and does not capture binaural loudness summation in
impaired listeners. It applies stationary loudness integration to a
static long-term average speech spectrum, whereas real speech fluctuates
and compression acting on it may yield different instantaneous loudness
@souza2002. The analysis is an index-level optimization without
behavioral validation. Finally, it used idealized thresholds (the ten
standard audiograms of #cite(<bisgaard2010>, form: "prose"), which
summarize a clinical database, and sixteen synthetic sweep audiograms)
and a single speech spectrum; individual patients would require measured
audiograms and varied speech inputs. The standard set contains no
audiogram with near-normal hearing through 1000 Hz and a steep loss
immediately above, the configuration for which the sweep found a
benefit. Steeply sloping losses are uncommon @bisgaard2010, but for them
the conclusion rests on the synthetic sweep.

The SII was computed in quiet. In noise, low-frequency attenuation also
changes how much noise reaches the ear and how much it masks upward, and
an open fitting passes environmental noise directly; these effects, like
the occlusion effect, own-voice quality, loss of the open-ear resonance,
and feedback, are outside the model.

The floor analyses were also conducted only at 65 dB SPL with linear
gain. Figure 1 shows the budget tightening as input level rises, which
would favor a larger floor effect for loud speech; however, additional
2--4 kHz gain already lowered the SII slightly at 65 dB SPL, and the
SII's level-distortion factor penalizes high presentation levels more
strongly. The
direction of the effect at 50 and 80 dB SPL therefore cannot be inferred
from these results and would require a level-specific (compression)
analysis.

The flat −10 dB floor likely overstates achievable attenuation in the
lowest bands, so the floor effects are likely optimistic estimates of the
benefit of passive attenuation. A frequency-shaped floor based on
measured insertion loss would be more realistic, although measured
attenuation depends strongly on earmold seal, insertion depth, and slit
leak.

The anchor penalty biases the floor effects in the opposite direction,
and its size was tested directly. The anchor-off solutions indicate what
an essentially unpenalized SII maximizer could achieve but are weakly
regularized and are not realistic prescriptions. The anchor-off solutions
remove the anchor's downward bias but keep the optimistic flat floor, so
apart from incomplete convergence they are an upper estimate of the floor
effect; the anchor-on solutions carry both biases, which act in opposite
directions. The anchor-off solutions are also not exact optima: in the four sweep pairs that left
budget unspent, additional 8 kHz gain would still have raised the SII by
0.002 to 0.003.

The two models also disagree near threshold. For the profound
audiogram N7, AUDMOD predicts zero loudness even for the NAL-NL2
fitting, so the iso-loudness cap is zero and that comparison is
degenerate, whereas the SII still credits a little audibility (0.07 for
the ANSI SII). The models reference threshold differently, AUDMOD
through supra-aural earphone reference levels and the SII through the
reference internal noise of ANSI S3.5-1997, so speech near threshold can
count as audible to one and not the other. The floor analyses concern
listeners with audible low-frequency speech, for whom the discrepancy
does not arise.

== Acknowledgments
<acknowledgments>
Generative artificial intelligence tools were used in preparing this work. Gemini 3.1 Pro
(Google DeepMind) served as a programming and copyediting assistant,
refactoring R and #box[C++] code and editing the manuscript text. Claude (Anthropic; Opus 5.5 and Sonnet 5 models) was used to
audit the analysis code and its outputs, to write diagnostic and
analysis scripts in R, to draft portions of the text, including the
abstract, and to locate and verify references against publisher
records. All reported analyses were run by the author. The author verified all code written with these
tools through numerical checks against independent outputs, reviewed and
edited all text drafted with them, and takes full responsibility for the
content, including the accuracy of all references.

== Conflict of Interest
<conflict-of-interest>
The author declares no conflicts of interest.

== Funding
<funding>
This work received no external funding.

== Data Availability
<data-availability>
The code used to execute the computational simulations, reproduce the
dataset, and generate the figures for this study is fully open-source
and available on GitHub (https://github.com/r-gregmisc/SII).

== References
<references>


#set bibliography(style: "jaaa.csl", title: none)
#show bibliography: set par(first-line-indent: 0em, hanging-indent: 0.5in)

#bibliography("jaaa_refs.bib")

#pagebreak()

== Figure Legends
<figure-legends>

#par(first-line-indent: 0em)[#strong[Figure 1.] Fraction of the normative loudness ceiling consumed by unamplified speech, for the ten standard audiograms (Table 1) at input levels of 50, 65, and 80 dB SPL. The ceiling is the loudness of unaided speech for a listener with typical hearing at that level, and is identical across profiles. The remainder of each bar's height to 100% is the budget available to purchase high-frequency audibility before any gain is prescribed. A 0 marks a level at which unamplified speech is inaudible to the model.]

#par(first-line-indent: 0em)[#strong[Figure 2.] Change in optimized insertion gain when the minimum-gain floor is relaxed from 0 dB to −10 dB, at a 0.5-sone loudness budget, by audible edge frequency (anchor penalty on; all 16 pairs matched in loudness). Grey lines show individual audiograms; the black line is their mean. Because the paired solutions are at matched loudness, loudness given up at one frequency is spent at another.]
