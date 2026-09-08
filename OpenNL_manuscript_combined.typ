== Abstract
<abstract>
#strong[Open-NL] is an open-source computational testbed designed for
the transparent modeling and evaluation of Wide Dynamic Range
Compression (WDRC) prescriptive rules. Modern prescriptions like NAL-NL2
rely on extensive empirical regularizations to ensure clinical safety.
These safeguards counteract the well-documented failures of pure
intelligibility maximization. However, clinical software remains
closed-source. This prevents researchers from isolating how specific
heuristic safeguards interact.

Open-NL addresses this limitation. It couples a multi-start Nelder-Mead
Speech Intelligibility Index (SII) optimizer with the Moore & Glasberg
(2004) specific-loudness model. We benchmark this testbed across a
$4^4 = 256$-permutation heuristic sweep. To mitigate the numerical
entrapment inherent to local simplex search on non-convex audiological
surfaces, the framework deploys a robust 5-iteration multi-start
initialization routine. Crucially, a sensitivity analysis reveals that
the optimizer actively collides with these mathematical boundary
conditions. Because the objective function is dominated by physiological
loudness constraints, modulating the underlying heuristic triggers
yielded exceptionally tight response envelopes. This indicates that once
the optimizer reaches the active penalty boundary, the underlying
heuristic parameters are rendered largely irrelevant, effectively
preventing runaway amplification but emphasizing the need to include
binding penalty parameters in future sensitivity sweeps.

Standard monaural models systematically underestimate real-world
binaural broadband summation. Therefore, this modeled loudness frontier
is strictly illustrative rather than clinically definitive. When
stripped of clinical heuristics, the optimizer dramatically inflates
high-frequency gain in profound profiles. This behavior demonstrates the
theoretical limits of pure mathematical optimization against real-world
clinical bounds. Open-NL exposes these critical trade-offs within a
fully inspectable framework. Ultimately, it provides the computational
substrate for future calibration workflows, paving the way to replace
static heuristic boundaries with individualized, distortion-aware
objective functions.

== I. INTRODUCTION
<i.-introduction>
Manufacturer-agnostic prescriptions remain central to evidence-based
hearing aid practice. While earlier investigations suggested that
generic targets might outperform proprietary first-fit algorithms on
patient preference and specific metrics (Valente et al., 2018),
contemporary evidence indicates that aided speech recognition in noise
often shows no significant difference across formulas (e.g., Cox et al.,
2012). However, while formula choice has relatively modest
intelligibility consequences in background noise, it drives substantial
variations in overall loudness, making modeled loudness (quantified in
sones per the Moore & Glasberg 2004 impaired loudness model) the primary
dependent variable in prescriptive evaluation.

While the derivations of major algorithms like NAL-NL2 and DSL m\[i/o\]
are published in detail, their software implementations remain
closed-source. Audiological science has long recognized that
unconstrained intelligibility maximization fails clinically without
extensive empirical regularization. For example, the evolution from
NAL-NL1 to NAL-NL2 required critical empirical corrections. These
included global gain reductions and reduced compression ratios for
severe losses. These safeguards were introduced specifically to
counteract the aggressive over-amplification provoked by pure
mathematical optimization (Keidser, Dillon, Carter, & O'Brien, 2012a).

Because clinical fitting software packages are compiled black boxes,
researchers cannot isolate individual heuristic rules. It remains
impossible to observe how specific safeguards interact within the
optimization cascade. Existing open-source tools serve distinct,
separate functional niches. The openMHA platform (Herzke et al., 2017)
operates as a real-time signal processing master hearing aid rather than
a target generator. The Cambridge CAM2/CAMEQ2-HF formulae (Moore et al.,
2010) provide rigidly defined equation-based targets rather than a
modular optimization sandbox. Finally, the Auditory Modeling Toolbox
(AMT; Majdak et al., 2022) offers loudness modeling without native
prescriptive inversion. Consequently, investigators cannot isolate a
specific prescriptive heuristic within an optimization loop without
reverse-engineering an entire proprietary engine.

Open-NL fills this gap. It provides a modifiable R substrate explicitly
designed for the modular ablation of prescriptive heuristics. By
coupling a Nelder-Mead desensitized SII optimizer to an integrated C++
specific-loudness engine, researchers can systematically disable,
isolate, or invert individual heuristics. For instance, investigators
can evaluate the upward spread of masking when disabling the 30 dB
conductive safety cap. This modular architecture aligns directly with
evolving audiological frameworks, such as the multi-profile philosophy
introduced in NAL-NL3 (Kitterick et al., 2026a).

Crucially, to benchmark this testbed without introducing confounding
variables, the optimization layer is embedded within a strictly
reproduced evaluation paradigm. The seven reference audiometric
profiles, the Moore & Glasberg (2004) specific-loudness model, and the
ANSI S3.5 SII metric utilized herein are a direct replication of the
methodological framework established by Johnson and Dillon (2011).
(Throughout this manuscript, "ANSI SII" refers to raw physical
audibility, whereas "smoothed desensitized SII" or "complete
desensitized SII" refers to audibility incorporating severe-loss
desensitization and level distortion penalties). Because this
physiological evaluation space is already established in the literature,
the primary contribution of this manuscript is the transparent
computational testbed itself. By exposing the behavior of numerical
solvers within this standardized sandbox, we clarify a crucial
distinction: while numerical solvers converge stably on any fixed
objective space, theoretical WDRC target generation exhibits acute
parameter sensitivity to uncalibrated heuristic boundaries, providing
the computational infrastructure necessary to quantify and calibrate
these interactions.

=== Clinical Safety and Usage Disclaimer
<clinical-safety-and-usage-disclaimer>
It is imperative to state unambiguously that Open-NL is strictly a
computational research testbed and #strong[must not be used for fitting
hearing aids on human listeners in its current form];. Because the
framework deliberately permits aggressive, over-prescriptive targets for
boundary testing---such as utilizing an aggressive 60 dB HL severe-loss
booster onset that permits aggressively high-frequency targets for
profound losses---it carries a significant risk of severe
over-amplification. As established by Ching, Dillon, Katsch, and Byrne
(2001), aggressive high-level targets in steeply sloping or profound
losses are precisely where over-amplification risks are greatest, as the
effectiveness of high-frequency audibility severely degrades as hearing
loss worsens (desensitization). The hypotheses and targets generated by
Open-NL represent extreme mathematical boundaries intended to trigger
experimental loudness rejection in controlled research settings, not
clinical solutions. Any future behavioral translation of this framework
requires independent institutional review, with mandatory real-ear
verification and strict, individualized loudness-tolerance limits
implemented as absolute prerequisites.

== II. ALGORITHM ARCHITECTURE
<ii.-algorithm-architecture>
=== A. Prescriptive Rationale and Objective Function
<a.-prescriptive-rationale-and-objective-function>
The choice of objective function is the primary design decision in any
prescriptive formula. It governs the fundamental trade-off between
intelligibility and comfort. Historically, established rationales occupy
distinct positions on this spectrum. NAL-NL2 maximizes speech
intelligibility while constraining overall broadband loudness to be less
than or equal to that of a normal-hearing listener (Keidser, Dillon,
Carter, & O'Brien, 2012a). Conversely, DSL m\[i/o\] normalizes loudness
across frequency to restore normal dynamic range perception (Scollie et
al., 2005). Finally, CAMEQ/CAM2 aim to equalize loudness across
frequency bands (Moore, Glasberg, & Stone, 2010).

Open-NL positions its prescriptive rationale as a #emph[constrained
intelligibility-maximizer];. Its primary mathematical objective is the
unconstrained maximization of desensitized SII. Rather than globally
restricting this maximization to a static "normal-or-less" loudness
boundary, Open-NL permits dynamic loudness growth. This growth continues
until it strikes a U-shaped physiological ceiling (controlled via
`cap_knots`; Section S.I.12). For severe losses, this penalty explicitly
permits slightly higher-than-normal loudness in the mid-frequencies,
where intelligibility yield is highest. However, it aggressively
decelerates loudness growth at spectral extremes.

Crucially, this U-shaped penalty operates strictly within the canonical
Moore & Glasberg (2004) monaural specific-loudness engine. It
dynamically restricts modeled monaural sones. However, it does not---and
mathematically cannot---account for the idiosyncratic binaural broadband
loudness summation observed in hearing-impaired listeners. In
normal-hearing auditory physiology, bilateral acoustic presentation
produces a modest binaural loudness summation. This is typically modeled
by a 2--6 dB level-dependent gain reduction.

However, robust psychoacoustic evidence demonstrates a stark contrast in
impaired ears. Binaural broadband summation in hearing-impaired
populations averages \~13 dB higher than in normal-hearing listeners.
This represents an unmodeled factor of $approx 2.4 times$ in linear
sones (Denk et al., 2025; Moore et al., 2014; Oetting et al., 2016,
2017). About 40% of hearing-impaired listeners (in a sample of 180)
exhibit excess summation far exceeding the normal range. Individual
summation values span a massive -10 to +40 dB envelope.

Standard monaural and narrowband loudness models cannot predict this
broadband suprathreshold phenomenon from the pure-tone audiogram alone.
Therefore, an algorithm optimized strictly beneath a monaural ceiling
becomes structurally anti-conservative when translated to bilateral
fittings. Consequently, Open-NL's U-shaped loudness constraint must be
interpreted strictly as an illustrative computational boundary for
single-ear simulation, rather than an empirical safety guarantee for
bilateral clinical use.

=== B. Methods and Development
<b.-methods-and-development>
The core ANSI SII calculation engine (the `sii()` function and
associated plotting routines) was originally developed by Gregory R.
Warnes for earlier package versions. Maintainership transferred to the
current author with version 1.1.0, at which point all subsequent Open-NL
prescriptive logic, clinical heuristics, and WDRC mathematical
implementations---including `open_nl()` and
`calculate_loudness()`---were developed by the author as original
contributions.

#emph[Declaration of Generative AI and AI-assisted technologies in the
research process:] In accordance with AIP Publishing guidelines, the
author explicitly discloses the use of Gemini 3.1 Pro (DeepMind, Google
LLC) during the preparation of this work as an interactive programming
and copyediting assistant. The AI was utilized strictly to refactor C++
and R algorithms, generate data visualizations, and condense manuscript
prose to adhere to JASA formatting standards. After using this tool, the
author rigorously reviewed and edited all outputs, taking full
accountability for the underlying algorithm design, theoretical
hypotheses, and final manuscript content. Specifically, to guarantee
computational integrity, all AI-assisted algorithmic refactoring was
systematically verified by the author via exact numerical regression
testing against pre-refactor outputs across the seven canonical
audiometric profiles, confirming absolute mathematical parity during
translation.

=== C. Algorithmic Pipeline and Execution Cascade
<c.-algorithmic-pipeline-and-execution-cascade>
The internal execution cascade of Open-NL comprises twelve strictly
ordered, modular processing stages: 1. #strong[Conductive Component
Separation & Baseline Partitioning];: Decomposing raw thresholds into
sensorineural components and air-bone gaps (ABGs). 2. #strong[Decoupled
Half-Gain Base Anchor Calculation];: Establishing a frequency-specific
base gain anchor
($G_(b a s e) = 0.46 dot.op upright("HTL")_(s n) + C_(i n t e r p)$)
decoupled from broadband PTA. 3. #strong[Experience-Level Shaping &
Log-Frequency $C_(v a l s)$ Interpolation];: Modulating
frequency-shaping arrays across discrete anchor frequencies based on
user experience (new, experienced, power). 4. #strong[Reverse-Slope
Low-Frequency Attenuation Floor];: Applying a bounded log-linear
low-frequency taper down toward a $- 10$ dB floor when low-frequency
loss exceeds high-frequency loss. 5. #strong[Slope-Dependent
Low-Frequency Penalty (SD-LFP) with Profound HF Bypass];: Dynamically
suppressing low-frequency gain for steeply sloping losses, gated when
high-frequency severity exceeds 70--95 dB HL. 6. #strong[Severe-Loss
Audibility Booster];: Providing an opt-in, bounded linear escalation
(slope = 0.15) for severe thresholds. 7. #strong[Soft-Compression
High-Frequency Desensitization];: Restricting excessive high-frequency
gain via a dynamic ceiling
($L_(g a i n) = 30 + 0.4 dot.op max \( 0 \, upright("HTL")_(s n) - 60 \)$)
and 2:1 soft compression. 8. #strong[Dynamic Range Mapping (LDL
Squeeze)];: Attenuating gain by 0.2 dB/dB of reduced dynamic range and
shifting baseline compression ratios. 9. #strong[Transducer Bandwidth
Roll-off];: Applying a continuous log-frequency piecewise multiplier
($M_(b w) in \[ 0.5 \, 1.0 \]$) to suppress unstable edge frequencies
($lt.eq 250$ Hz and $gt.eq 6000$ Hz). 10. #strong[Multi-Channel WDRC
Mapping, LTASS Pivot, and Demographic Adjustments];: Calculating dynamic
compression ratios, variable compression thresholds, piecewise
linear-compressive splines, and demographic offsets. 11.
#strong[Acoustic Venting, Coupling Loss, and Receiver Saturation
Limits];: Integrating real-ear insertion loss vectors across 10 coupling
types with a feedback safety floor, and capping MPO/SSPL90 receiver
limits at 120 dB SPL. 12. #strong[Embedded Nelder-Mead Simplex
Optimization & Physiological Loudness Ceilings];: Iteratively refining
multi-level gain curves against a multi-term objective loss function
incorporating U-shaped specific-loudness caps, compression ratio
ceilings, and spectral smoothness constraints.

The exact mathematical formulations, closed-form piecewise equations,
and complete parameter specifications for all twelve stages are provided
in full detail in the accompanying #strong[Supplementary Material];.

=== D. Consolidated Constants and Evidentiary Asymmetry
<d.-consolidated-constants-and-evidentiary-asymmetry>
Because Open-NL functions as a modifiable computational testbed, several
structural parameters remain mathematically uncalibrated: the 0.46 gain
anchor, 0.15 severe-loss booster slope, 70 dB HL booster onset (or 60 dB
HL in aggressive mode), 15 dB slope trigger, 20 dB taper width, -10 dB
reverse-slope floor, 70 dB HL bypass, 30 dB/0.4 $L_(g a i n)$
constraint, 0.2 dB/dB dynamic range squeeze, 75% air-bone-gap
restoration fraction, and 1.5:1 Comfort-in-Noise (CIN) compression clamp
(Table S1).

Crucially, an inspection of these heuristics reveals a profound
asymmetry in evidentiary support. Several prominent constants---most
notably the 75% air-bone-gap restoration rule and the 1.5:1
Comfort-in-Noise clamp---are pragmatic engineering choices without
direct empirical derivation. The 75% ABG fraction, while standard in
clinical prescriptive software (Johnson, 2013a) to avoid receiver
saturation and MPO clipping, has never been empirically established
against patient preference or speech recognition. Similarly, the 1.5:1
CIN clamp is an asserted heuristic inspired by NAL-NL3 (Kitterick et
al., 2026b) to mitigate listening fatigue, but lacks independent
perceptual validation. In sharp contrast, the 3.0:1 Compression Ratio
(CR) upper ceiling enforced across the WDRC stages and optimizer loss
function represents the best-supported constant in the framework. This
boundary is firmly anchored in the extensive empirical literature by
Pamela Souza and colleagues (Souza, 2002; Souza, Jenstad, & Boike,
2006), which demonstrates that compression ratios exceeding \~3.0:1
cause severe temporal envelope flattening, loss of acoustic contrast,
and speech-in-noise deficits. Documenting this asymmetry prevents
conflating validated psychoacoustic limits with arbitrary engineering
heuristics.

=== E. Framework for Principled Calibration
<e.-framework-for-principled-calibration>
For a computational testbed to provide lasting inferential value,
demonstrating parameter instability must be paired with a rigorous
calibration pathway. Future research can utilize Open-NL within a global
stochastic optimization framework (e.g., genetic algorithms or particle
swarm optimization) to systematically calibrate these heuristic gates.
In this architecture, an outer optimization loop searches the
multidimensional space of heuristic constants (e.g.,
$G_(b a s e) in \[ 0.3 \, 0.6 \]$, booster onset $in \[ 50 \, 80 \]$ dB
HL, low-frequency slope $in \[ 0 \, 0.5 \]$). For each candidate vector,
the inner Open-NL engine generates discrete WDRC targets across a
representative clinical corpus (e.g., NHANES). These targets are
evaluated through a time-domain acoustic simulation pipeline (e.g.,
openMHA; Herzke et al., 2017) using speech perception metrics like HASPI
and HASQI (Kates & Arehart, 2022).

Crucially, the outer-loop objective function must incorporate an
asymmetric, veto-based cost function: any parameter configuration
violating individualized broadband loudness tolerance (trueLOUDNESS;
Oetting et al., 2017) in simulated outlier listeners must incur an
overwhelming penalty. As detailed in Section II.A, because excess
binaural broadband summation cannot be predicted from pure-tone
thresholds, static 2--6 dB bilateral corrections are structurally
inadequate. Subordinating population-level intelligibility maximization
to individualized physiological safety limits transforms prescriptive
derivation into a reproducible, distortion-aware computational science.

#strong[TABLE I. Comprehensive Enumeration of Open-NL Free Parameters
and Evidentiary Derivation.]

#figure(
  align(center)[#table(
    columns: (25%, 25%, 25%, 25%),
    align: (left,left,left,left,),
    table.header([Parameter Category], [Specific Free
      Parameters], [Default / Evaluated Value], [Evidentiary Support &
      Derivation],),
    table.hline(),
    [#strong[Objective Penalties];], [Loudness Cap Knots
    (`cap_knots`)], [$L_(c a p)$ vectors (Section S.I.12)], [Derived
    from normal/impaired physiological loudness growth models.],
    [], [Optimizer Penalty Weights
    ($lambda_(1 - 8)$)], [$lambda_1 = 450 \, dots.h \, lambda_8 = 20$
    (Sec S.I.12)], [Pragmatic engineering constraints balancing target
    convergence.],
    [], [CR Soft Penalty Target ($P_(c r)$)], [$lt.eq 3.0 : 1$
    Compression Ratio], [#strong[Strong empirical derivation];: Souza
    (2002) speech degradation limits.],
    [#strong[Prescriptive Anchors];], [Base Gain Anchor
    ($G_(b a s e)$)], [0.46], [Uncalibrated midpoint balancing half-gain
    rules and preference data.],
    [], [New-User Offset ($Delta_(e x p)$)], [0 to -6 dB based on
    PTA], [Assumed heuristic approximating acclimatization
    preferences.],
    [], [Severe-Loss Booster (Slope / Onset)], [0.15 slope / 70 dB HL
    onset], [Assumed heuristic assisting profound loss without explosive
    recruitment.],
    [], [ABG Restoration Fraction], [75% (Linear)], [Engineering choice
    preventing hardware saturation (Johnson, 2013a).],
    [#strong[Compression Limits];], [Compression Kneepoint (CT)
    Range], [30 to 45 dB SPL], [Pragmatic limit aligning with standard
    real-world WDRC kneepoints.],
    [], [High-Frequency Soft-Compression], [Base 30 dB, Slope
    0.4], [Heuristic managing upward spread of masking in severe
    losses.],
    [], [DR Squeeze / CR Shift], [0.2 dB/dB, 0.02 CR/dB], [Heuristics
    fitting speech envelope into reduced physiological space.],
    [], [MPO/LDL Predictor Coefficients], [See Stage 8], [Statistical
    predictions based on population normative UCL datasets.],
    [#strong[Frequency Limits];], [Reverse-Slope Floor], [-10
    dB], [Cautious heuristic preventing masking of intact basal cochlear
    units.],
    [], [Dead Region / Transducer Roll-off], [30 dB/oct past $1.7 f_e$,
    $w_(b w)$], [Standard transducer limits and dead-region literature
    (Moore, 2001).],
    [], [Acoustic Coupling Loss], [Occluded/Vented Vectors (Table
    S4)], [Deterministic physical hardware measurements.],
  )]
  , kind: table
  )

== III. ANALYTICAL CENTERPIECE: DISTINGUISHING HEURISTIC SENSITIVITY FROM SOLVER STOCHASTICITY
<iii.-analytical-centerpiece-distinguishing-heuristic-sensitivity-from-solver-stochasticity>
The primary scientific contribution of the Open-NL framework is not the
specific targets it generates, but the transparent computational
infrastructure it provides for evaluating prescriptive heuristics.
Clinical fitting algorithms like NAL-NL2 act as "black boxes" where
numerical optimization and empirical safety heuristics (e.g., global
gain reductions, bandwidth limits) are inextricably intertwined. Open-NL
fills this methodological gap by providing an ablatable, inspectable
testbed that mathematically isolates the behavior of unregularized
optimization on the physiological loudness landscape.

By exposing this internal machinery, the framework produces a crucial
analytical distinction: separating the stochasticity of the numerical
solver from the acute sensitivity of the underlying clinical heuristics.
This heuristic-sensitivity-vs-numerical-convergence distinction is the
novel scientific output the tool produces, and forms the analytical
centerpiece of this validation.

=== A. Heuristic Parameter Sensitivity vs.~Numerical Convergence Stability
<a.-heuristic-parameter-sensitivity-vs.-numerical-convergence-stability>
==== 1. Multi-Parameter Sensitivity Sweep
<multi-parameter-sensitivity-sweep>
To isolate heuristic sensitivity from numerical solver stochasticity, an
ANOVA variance decomposition (reporting $eta^2$ effect sizes) was
executed across 256 permutations of four primary algorithmic
constraints: the base gain anchor (0.40 to 0.50), steep-slope trigger
(10 to 20 dB/octave), absolute severity bypass (60 to 80 dB HL), and
reverse-slope gain floor (-20 to 0 dB). These 256 unique parameter
permutations were evaluated independently on each of the most
topologically unstable profiles (A2, A4, A5)---yielding 768 total
permutation runs (256 per profile)---executed with the aggressive 60 dB
HL booster mode engaged to directly probe boundary interactions.

#strong[TABLE II. ANOVA Variance Decomposition of Heuristic Parameters
(65 dB SPL Input).] #emph[Note: Generated using the aggressive 60 dB HL
booster onset. The ANOVA decomposition explicitly separates variance
explained by clinical heuristics from residual solver stochasticity.]

#figure(
  align(center)[#table(
    columns: (25%, 25%, 25%, 25%),
    align: (auto,auto,auto,auto,),
    table.header([Profile], [Median Desensitized SII \[Min,
      Max\]], [Median Loudness \[Min, Max\]], [ANOVA Dominant Factor
      ($eta^2$)],),
    table.hline(),
    [#strong[A2];], [0.87 \[0.82, 0.88\]], [4.43 \[3.38,
    4.44\]], [Anchor (61.1%)],
    [#strong[A4];], [0.64 \[0.62, 0.66\]], [5.27 \[5.23, 5.28\]], [None
    (Total Variance \< 0.1 sones)],
    [#strong[A5];], [0.45 \[0.45, 0.51\]], [4.28 \[4.26, 4.37\]], [None
    (Total Variance \< 0.2 sones)],
  )]
  , kind: table
  )

The resulting variance (#strong[Table II];, #strong[Figure 1];)
illustrates mechanistically how strict mathematical boundary conditions
dominate the objective landscape. The tight response envelope is not
evidence of a flat optimization space, but rather demonstrates that the
optimizer actively collides with the binding physiological loudness
constraint. For example, the interpolated loudness caps for profiles A1,
A3, and A5 effectively dictate the final modeled loudness to within 0.1
sones. Because the objective function is entirely bound by these hard
distortion penalties, modulating the underlying heuristic triggers
failed to produce any significant main effect (e.g., A5 fluctuating
narrowly between 4.26 and 4.37 sones purely due to higher-order
interactions). This indicates that once the active penalty wall is
reached, the underlying heuristic parameters are rendered practically
irrelevant. While this successfully prevents the massive runaway
amplification typical of historically unregularized intelligibility
optimization, any future claims of comprehensive parameter robustness
must be tested against a sweep that formally includes these binding
penalty variables.

#box(image("figures/Figure1_Sensitivity.png")) #emph[Figure 1.
Distribution of resulting ANSI SII scores and physiological loudness
penalties across 768 permutations (256 $times$ 3 profiles) for clinical
profiles A2 (Reverse Slope), A4 (Severe), and A5 (Profound),
illustrating how the active physiological loudness constraint dominates
the optimization space, severely restricting the variance caused by
heuristic parameter modifications.]

==== 2. Numerical Convergence Stability: Nelder-Mead Limitations and Future Stochastic Solvers
<numerical-convergence-stability-nelder-mead-limitations-and-future-stochastic-solvers>
A sharp distinction must be maintained between #strong[heuristic
parameter sensitivity] (target shifts resulting from altered clinical
rules; Section III.A.1) and #strong[numerical convergence stability]
(solver consistency on a fixed ruleset). In non-linear optimization, the
topology of hearing aid fitting targets is notoriously ill-behaved. The
objective landscape contains narrow, curved valleys, non-differentiable
step boundaries (e.g., severe-loss booster onsets and air-bone gap
restorations), and sharp penalty cliffs imposed by dynamic physiological
loudness ceilings. On such non-convex, multimodal surfaces, local
downhill solvers like the Nelder-Mead simplex algorithm are notoriously
prone to premature stagnation, simplex collapse, and entrapment in
shallow local extrema.

Indeed, unconstrained Nelder-Mead search from disparate flat
initializations (e.g., -10 dB vs.~+10 dB) can deviate by up to 0.5 sones
or 0.05 SII. To mitigate this, Open-NL deploys a 5-iteration multi-start
routine---seeding the initial simplex with the NAL-R target and
executing four additional randomized restarts.

Because the ANOVA decomposition demonstrated that the heuristic rules
had minimal main effects on the steeply sloping profiles (A4, A5), the
absolute variance observed across the sweep was exceptionally tight (a
total range of just 0.05 sones for A4). However, this residual variance
represents a convolution of highest-order heuristic interactions and
solver stochasticity. Consequently, this sweep cannot strictly isolate
pure numerical stability. Future investigations must formally evaluate
Nelder-Mead solver consistency by executing dedicated Monte Carlo
initializations with fixed parameter vectors across hundreds of varying
RNG seeds.

Furthermore, while the algorithm tightly constrains profiles like A4 and
A5 against the physiological loudness cap, other profiles exhibit
significant heuristic sensitivity. For example, profile A2 experiences
wide target swings (3.38 to 4.44 sones) systematically driven by the
anchor heuristic (61.1% variance). Because physiological optimization
constraints often create flat topological plateaus near the optimal
basin, divergent parameter configurations can theoretically produce
functionally equivalent objective scores. Future implementations
analyzing parameter identifiability should transition to modern global
stochastic optimization algorithms:

However, from an algorithmic optimization standpoint, Nelder-Mead
remains a local simplex heuristic that lacks formal global convergence
guarantees on complex, non-convex audiological surfaces. While
multi-start seeding with NAL-R provides a practical, computationally
efficient substrate for local ablation testing within R, #strong[future
iterations of prescriptive target optimizers should transition to modern
global stochastic optimization algorithms];: 1. #strong[Genetic
Algorithms (GAs)];: By maintaining a diverse population of candidate
gain configurations and applying stochastic crossover and mutation
operators, GAs can natively explore multimodal search spaces without
stalling at sharp non-differentiable penalty boundaries (such as
unrelaxed desensitization thresholds or dynamic MPO caps). 2.
#strong[Differential Evolution (DE)];: DE is exceptionally well-suited
for continuous multi-channel gain optimization. Its vector-difference
mutation mechanism enables self-adaptive search across non-convex
landscapes, effectively escaping the local attractor basins that trap
simplex algorithms in steeply sloping audiograms. 3. #strong[Particle
Swarm Optimization (PSO)];: PSO models candidate solutions as particles
traversing the fitness space, balancing individual exploration with
swarm cognitive memory. This provides rapid convergence across
multi-channel parameter sweeps while maintaining robust resistance to
local minima.

Crucially, adopting population-based global stochastic solvers
eliminates the need for artificial mathematical relaxations (such as the
smoothed $K'_(s m o o t h e d)$ desensitization approximation), allowing
optimizers to evaluate raw, discontinuous physiological boundaries
directly. Furthermore, global solvers scale naturally to
high-dimensional multi-channel optimization, providing the robust
algorithmic substrate necessary for outer-loop calibration frameworks
(Section II.E). Nevertheless, as noted by Dao et al.~(2021), physical
real-ear-to-coupler differences (RECD) and acoustic coupling leakages
cause real-world fittings to deviate most severely from theoretical
targets at thresholds above 85 dB HL, meaning numerical convergence on
mathematical audiograms must not be misconstrued as physical clinical
reliability.

=== B. Worked Demonstration: Isolating the Shared Binaural Loudness Vulnerability
<b.-worked-demonstration-isolating-the-shared-binaural-loudness-vulnerability>
While the previous section established the tool's numerical stability,
applying it to a physiological boundary problem demonstrates its
analytical utility. A central problem in modern audiology is that
standard clinical models operate on a monaural basis, failing to account
for idiosyncratic binaural broadband loudness summation. The fact that
established prescriptions like NAL-NL2 share this vulnerability to
unpredictable binaural loudness is precisely why having an open,
parameterizable model like Open-NL is valuable: it provides a testbed to
isolate and simulate the effect of this field-wide blind spot without it
being buried under opaque empirical corrections.

The following comparison between Open-NL and NAL-NL2 is therefore not
presented as a finding about Open-NL's amplification superiority, but as
a worked demonstration of the framework's ability to expose structural
vulnerabilities that the field cannot solve from the pure-tone audiogram
alone.

To benchmark Open-NL without confounding variables, the optimization
layer is evaluated within the established 7-profile paradigm of Johnson
and Dillon (2011), comparing targets directly against NAL-NL2 version 2
software (National Acoustic Laboratories, Sydney, Australia) for soft
(50 dB SPL), conversational (65 dB SPL), and loud (80 dB SPL) speech
inputs. All NAL-NL2 targets were extracted using an 18-channel
compression architecture with adaptive time constants, occluded BTE \#13
tubing, and supra-aural headphone thresholds. Crucially, to isolate the
pure mathematical objective function without demographic artifacts, both
Open-NL and NAL-NL2 targets were generated using identical baseline
configurations: #strong[Bilateral, Adult, Unknown Gender, Experienced
user, and Non-tonal language];. Both sets are reported strictly as
Real-Ear Insertion Gain (REIG) in the identical acoustic reference plane
with matched occluded coupling. To ensure absolute scoring parity, both
Open-NL and NAL-NL2 final targets were mathematically evaluated through
the exact same objective metric engine: the ANSI/ASA S3.5-1997 (R2024)
standard, utilizing the critical-band calculation procedure (21 bands)
and the Normal vocal effort Long-Term Average Speech Spectrum (LTASS).
Restricting comparisons to NAL-NL2 provides a standardized, universally
recognized clinical baseline, avoiding the artifacts of surrogate target
estimators for alternative proprietary formulae.

=== Shared Monaural Vulnerability: The Rationale for Aggressive Boundary Testing
<shared-monaural-vulnerability-the-rationale-for-aggressive-boundary-testing>
A critical question arises regarding the experimental design of this
benchmark: could Open-NL simply deactivate its severe-loss booster to
achieve monaural loudness parity with NAL-NL2, thereby "validating" the
prescription against the clinical standard? Indeed, in default
conservative mode (booster onset at 70 dB HL or disabled), Open-NL
yields monaural loudness values closely aligned with NAL-NL2 across
primary sensorineural profiles. However, using conservative parity to
claim clinical validation would obscure the central theoretical lesson
of this computational testbed.

Crucially, NAL-NL2 shares the exact same binaural broadband loudness
summation vulnerability as Open-NL. NAL-NL2 applies the identical,
standard level-dependent 2--6 dB bilateral reduction derived from
normal-hearing listeners, failing equally to account for the excess
broadband summation documented in hearing-impaired populations (see
Section II.A). The reason NAL-NL2 does not trigger widespread clinical
loudness rejection is not because its underlying loudness model is
physiologically complete, but because its empirical derivations
incorporated heavy, post-hoc regularizations---including global gain
reductions (-2 dB for females, -3 dB for new users), compressed dynamic
range ceilings, and conservative high-frequency roll-offs---combined
with routine clinical reliance on the $plus.minus 15$ dB volume control
in fitting software (Keidser et al., 2012a).

By intentionally executing this evaluation with the aggressive 60 dB HL
booster mode engaged, Open-NL deliberately strips away these empirical
dampers. This stress-testing reveals that when an unregularized
numerical optimizer operates strictly beneath standard monaural loudness
models, it aggressively pushes high-frequency gain and exploits the
objective function, producing targets that are structurally
anti-conservative for bilateral fittings. Rather than merely mimicking
NAL-NL2's output envelope, Open-NL's diagnostic value lies in
demonstrating that relying exclusively on static monaural loudness
assumptions introduces substantial anti-conservative risks for the
significant cohort of patients (30--40%) exhibiting excess bilateral
summation. This strongly suggests that future prescriptive frameworks
(e.g., NAL-NL3 and Open-NL v2) cannot resolve bilateral loudness through
static audiometric equations, but must directly integrate individualized
broadband loudness scaling (#emph[trueLOUDNESS];; Oetting et al., 2017)
into their objective functions.

Two critical methodological boundaries govern this evaluation: 1.
#strong[The Constrained Metric Tautology Warning];: A fundamental
circularity exists when evaluating an optimization algorithm against the
identical metric it was tuned to maximize. Because Open-NL's objective
function seeks to maximize desensitized SII, reporting higher SII values
relative to regularized formulae (like NAL-NL2) is generally expected.
However, examining the full distribution in Table III reveals that
Open-NL's objective exploitation manifests through three distinct
mechanical pathways: - #strong[Active Constraint Inversions (A4, A5)];:
As previously noted, Open-NL yields #emph[lower] desensitized SII than
NAL-NL2 for A4 (0.62 vs.~0.68) and A5 (0.44 vs.~0.54). Here, the
U-shaped physiological loudness cap forces the solver to explicitly
sacrifice theoretical audibility to prevent catastrophic loudness
growth. - #strong[Solver Entrapment and Pareto Domination (A1, A2)];:
For profile A2, Open-NL is strictly Pareto-dominated by NAL-NL2: it
yields a lower desensitized SII (0.77 vs.~0.78) while being drastically
louder (4.44 vs.~3.43 sones). This occurs because Nelder-Mead becomes
trapped against the active 4.44-sone penalty wall. Lacking the ability
to accept temporary uphill loss to traverse the non-convex landscape,
the local simplex solver fails to locate NAL-NL2's objectively superior
gain allocation. This starkly demonstrates the necessity of
transitioning to global stochastic solvers (Section III.A.2). -
#strong[Inefficient Objective Exploitation (A6, A7)];: For profile A6,
Open-NL blindly trades a massive 1.36 sones of excess loudness to buy a
marginal +0.04 increase in SII. For A7 (a purely deterministic
conductive correction), Open-NL yields +0.62 sones for zero additional
SII gain. This behavior highlights the inherent danger of pure
unregularized optimization: algorithms will indiscriminately sacrifice
patient comfort for statistically insignificant fractions of objective
audibility unless heavily penalized.

Ultimately, stationary band-importance metrics like ANSI S3.5 and
desensitized SII are blind to dynamic temporal envelope distortion,
channel cross-talk, and phase distortion induced by aggressive
compression ratios. In auditory science, genuine, independent,
distortion-aware speech perception evaluation requires waveform-level
biophysical models: - HASPI (Hearing Aid Speech Perception Index; Kates
& Arehart, 2022): Accurately simulates peripheral auditory processing,
basilar membrane compression loss, auditory nerve firing rates, and
envelope modulation integrity. - HASQI (Hearing Aid Speech Quality
Index; Kates & Arehart, 2022): Evaluates non-linear harmonic distortion,
envelope fidelity, and spectral fine-structure cross-correlation between
aided and reference speech signals. Computing HASPI and HASQI requires
convolving continuous speech (.wav) through a time-domain dynamic range
compression engine (such as openMHA; Herzke et al., 2017). Because
Open-NL currently operates strictly at the steady-state prescriptive
target level (Johnson & Dillon, 2011), it lacks the native time-domain
waveform processing required to compute HASPI and HASQI. Consequently,
the objective metric differentials reported in Table III and Figure 3
are presented as theoretical bounds tests---quantifying the mathematical
consequences of removing clinical heuristics---rather than as direct
clinical superiority claims. 2. #strong[Binaural Loudness Summation and
the Collapse of Monaural Frontiers];: The comparative loudness
evaluations are fundamentally bounded by the limitations of monaural
auditory modeling. While standard clinical software applies a nominal 2
to 6 dB bilateral gain reduction, this static correction reflects
normal-hearing physiology and fails catastrophically for broadband
speech in impaired listeners. As detailed in Section II.A, a significant
cohort of hearing-impaired listeners exhibits extreme excess binaural
broadband loudness summation that deviates heavily from normal-hearing
models (van Beurden et al., 2021; Pieper et al., 2021; Denk et al.,
2025). Crucially, because excess summation is a broadband,
suprathreshold #emph[sensorineural] effect that does not correlate with
pure-tone audiograms, an optimization routine operating beneath a
monaural ceiling (e.g., 4.32 sones for profile A5) appears
mathematically safe in isolation, yet predictably collapses into acute
acoustic intolerance when fitted bilaterally. Furthermore, there is no
physiological basis for applying such excess summation models to purely
conductive etiologies (e.g., A7). Because applying a fixed scalar to
monaural outputs assumes normal-hearing loudness growth---the exact
structural flaw this framework critiques---Table III reports canonical
single-ear monaural loudness exclusively. True bilateral predictions
require propagating the dynamic full-range signal through a non-linear
binaural loudness engine.

To execute this evaluation natively in R, the `SII` package implements a
fast C++ port of the canonical Moore & Glasberg (2004) stationary
specific-loudness model via `Rcpp`. (Note: As stated in the AI
Declarations, the internal R-to-C++ translation was verified to absolute
mathematical parity via numerical regression testing).

To externally cross-check this stationary implementation, native C++
predictions were evaluated against the Auditory Modeling Toolbox (AMT;
Majdak et al., 2022) across 45 discrete test points (5 profiles \$
imes\$ 9 input levels from 50 to 90 dB SPL). Specifically, Open-NL's
stationary outputs were compared against AMT's `bramslow2004` function.
It is critical to note that this is not a direct port comparison, but
rather a cross-algorithmic validation: Open-NL integrates the
steady-state algebraic power spectrum directly, whereas AMT's
`bramslow2004` runs a physical 2400-sine-wave stimulus with random
phases through a simulated time-domain digital filterbank. Because the
time-domain model inherently captures the transient crest-factor peaks
of the crest-factored noise waveform, exact machine-precision agreement
is mathematically impossible.

Despite these fundamentally distinct modeling pathways (stationary
spectral integration vs.~dynamic time-domain waveform simulation), the
models exhibited excellent approximate convergence: a mean bias of just
$+ 0.23$ sones and a Mean Absolute Error (MAE) of $0.39$ sones
(#strong[Figure 2];).

#box(image("figures/Figure2_BlandAltman.png")) #emph[Figure 2.
Difference plot demonstrating excellent approximate convergence between
Open-NL's stationary spectral C++ engine and AMT's dynamic time-domain
simulation (`bramslow2004`) across 45 canonical evaluation points.]

For mixed and conductive profiles (A6, A7), direct AMT benchmarking was
omitted because canonical AMT lacks native air-bone gap parameters,
whereas our C++ engine algorithmically extends the model to treat the
conductive component as a linear pre-cochlear attenuator, in accordance
with standard audiological principles (Dillon, 2012).

#strong[TABLE III. Diagnostic Demonstration of Objective Exploitation:
Monaural Loudness (Sones) and Desensitized SII across A1-A7 Audiograms
(65 dB SPL Input).] #emph[Note: Open-NL targets are presented for both
Conservative (booster onset 70 dB HL) and Aggressive (onset 60 dB HL)
modes for steeply sloping profiles (A4, A5). For profiles not exceeding
60 dB HL (A1-A3, A6-A7), the booster does not engage and outputs are
identical across modes, designated simply as 'Open-NL'. The comparative
columns illustrate theoretical boundaries of optimization against
clinical anchors.]

#figure(
  align(center)[#table(
    columns: (20%, 20%, 20%, 20%, 20%),
    align: (auto,auto,auto,auto,auto,),
    table.header([Profile], [Formula], [ANSI SII], [Desensitized
      SII], [Monaural Loudness (Sones)],),
    table.hline(),
    [A1], [NAL-NL2], [0.82], [0.76], [4.29],
    [A1], [Open-NL], [0.82], [0.76], [4.44],
    [A2], [NAL-NL2], [0.84], [0.78], [3.43],
    [A2], [Open-NL], [0.85], [0.77], [4.44],
    [A3], [NAL-NL2], [0.71], [0.67], [3.92],
    [A3], [Open-NL], [0.72], [0.67], [4.20],
    [A4], [NAL-NL2], [0.71], [0.68], [6.09],
    [A4], [Open-NL (Conservative)], [0.58], [0.55], [5.22],
    [A4], [Open-NL (Aggressive)], [0.65], [0.62], [5.27],
    [A5], [NAL-NL2], [0.57], [0.54], [5.53],
    [A5], [Open-NL (Conservative)], [0.47], [0.44], [4.26],
    [A5], [Open-NL (Aggressive)], [0.47], [0.44], [4.32],
    [A6], [NAL-NL2], [0.79], [0.75], [2.12],
    [A6], [Open-NL], [0.85], [0.79], [3.48],
    [A7], [NAL-NL2], [0.97], [0.92], [1.15],
    [A7], [Open-NL], [0.97], [0.92], [1.77],
  )]
  , kind: table
  )

#strong[TABLE IV. Insertion Gain Targets (dB) across A1-A7 Audiograms
(65 dB SPL Input).] #emph[Note: Open-NL targets are presented for both
Conservative and Aggressive modes for A4 and A5. Targets illustrate how
unconstrained desensitized SII maximization allocates high-frequency
gain relative to regularized formulae. Profile A7 is fully deterministic
(0.75 x 50 dB = 37.5 dB) and is included strictly as an arithmetic
sanity check.]

#figure(
  align(center)[#table(
    columns: (12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%),
    align: (auto,auto,auto,auto,auto,auto,auto,auto,),
    table.header([Profile], [Formula], [250 Hz], [500 Hz], [1000
      Hz], [2000 Hz], [4000 Hz], [8000 Hz],),
    table.hline(),
    [A1], [NAL-NL2], [0.0], [0.0], [7.3], [12.1], [18.0], [19.1],
    [], [Open-NL], [0.0], [7.2], [15.8], [18.4], [22.0], [12.8],
    [A2], [NAL-NL2], [10.1], [9.3], [12.2], [8.3], [3.9], [4.0],
    [], [Open-NL], [11.8], [18.0], [20.4], [13.8], [8.2], [2.5],
    [A3], [NAL-NL2], [0.0], [0.0], [9.9], [16.8], [20.7], [21.6],
    [], [Open-NL], [0.0], [7.2], [20.4], [23.0], [24.3], [12.8],
    [A4], [NAL-NL2], [0.0], [0.0], [0.9], [12.5], [21.8], [21.8],
    [], [Open-NL], [0.0], [0.0], [6.6], [18.4], [32.7], [18.9],
    [A5], [NAL-NL2], [0.0], [0.0], [6.6], [20.7], [27.1], [26.6],
    [], [Open-NL], [0.0], [0.0], [11.2], [27.6], [38.8], [23.5],
    [A6], [NAL-NL2], [22.5], [24.2], [32.9], [35.6], [41.4], [42.6],
    [], [Open-NL], [23.6], [31.4], [37.8], [39.1], [43.2], [34.0],
    [A7], [NAL-NL2], [34.7], [34.6], [34.7], [34.8], [35.0], [35.1],
    [], [Open-NL], [37.5], [37.5], [37.5], [37.5], [37.5], [37.5],
  )]
  , kind: table
  )

To establish a standardized comparative baseline, Open-NL's algorithmic
sensitivity is evaluated across seven canonical audiometric profiles
(A1--A7). Profiles A1--A5 represent the standard sensorineural
configurations utilized by Johnson & Dillon (2011) (derived from the
foundational profiles of Byrne), spanning mild-sloping (A1),
reverse-slope (A2), and severe to profound (A4, A5) pathologies.
Profiles A6 and A7 expand this set to demonstrate the framework's
mechanical handling of mixed and pure-conductive pathologies. While
evaluating a large-scale real-world corpus (e.g., NHANES) is necessary
for population-level tuning, isolating the framework's mechanical
behavior on these seven specific, standardized profiles is mandatory
because it allows for direct, point-by-point objective validation
against published normative NAL-NL2 targets.

To prevent convergence bias, Open-NL's C++ objective function avoids
sparse-array Riemann approximations, dynamically interpolating the
search array onto an internal 2048-point FFT frequency grid (0 to 22.05
kHz). For mild-to-moderate losses (A1, A3), Open-NL expands soft speech
(50 dB inputs) slightly more aggressively than NAL-NL2 to maximize
audibility within the safe physiological envelope, while compressing
higher-level inputs to maintain loudness parity (#strong[Figure 3];,
#strong[Figure 4];).

#box(image("figures/Figure3_SII_Comparison.png", width: 100.0%))
#emph[Figure 3. Comparison of ANSI SII (Raw Physical Audibility) vs
Desensitized SII for NAL-NL2 and Open-NL across 50, 65, and 80 dB SPL
Inputs.]

#box(image("figures/Figure4_Insertion_Gain.png", width: 100.0%))
#emph[Figure 4. Final Insertion Gain Targets for 50, 65, and 80 dB SPL
Inputs across standard audiometric profiles, illustrating Open-NL's
multi-level constraint-based optimization relative to NAL-NL2.]

For severe and profound losses (A4, A5), unmodified SII maximization
drives substantial high-frequency gain. Although Open-NL integrates
desensitization penalties to temper this drive, it still prescribes
substantially more high-frequency gain than NAL-NL2 (e.g., +10.9 dB at 4
kHz for A4, and +11.7 dB for A5 at 65 dB SPL inputs; Table IV). In
listeners with severe loss, reduced spectral resolution, elevated
hearing thresholds, and cochlear dead regions account for comparable
shares of speech recognition variance, with dead regions specifically
blunting the benefit of restored high-frequency audibility (Ching,
Dillon, & Byrne, 1998; Baer, Moore, & Kluk, 2002; Vestergaard, 2003;
Souza et al., 2018; Moualed, Humphries, & Ramsden, 2018). While high
prescribed gain increases physical audibility on paper, it severely
degrades perceptual clarity if suprathreshold distortion is unmodeled
(Margolis et al., 2025). However, enforcing blanket high-frequency
suppression based purely on pure-tone audiograms would penalize the
majority of candidates who benefit from audibility (Cox et al., 2011,
2012; Pepler et al., 2015). Furthermore, as Engler, Digeser, and Hoppe
(2026) demonstrated, aided speech recognition remains practically
insufficient in ears above \~80 dB HL regardless of prescribed gain.
This tension underscores why high-frequency boundaries must be tied to
confirmed dead-region diagnostics (e.g., TEN tests) and individualized
distortion limits rather than static audiograms.

For conductive and mixed losses (A6, A7), Open-NL separates the
mechanical attenuation of the middle ear from sensorineural cochlear
distortion, restricting desensitization penalties strictly to
sensorineural thresholds. In profile A7 (pure conductive loss with a 50
dB air-bone gap), the output is fully deterministic: the 75% ABG
restoration rule mandates an exact, flat 37.5 dB of linear gain across
frequencies and levels. Because the optimizer contributes nothing to
this solution and both formulas mechanically converge on ANSI SII 0.97,
A7 is included in the tables strictly as an arithmetic sanity check
rather than a comparative optimization finding. Crucially, this 75%
restoration rule is an engineering choice adapted from clinical
conventions (Johnson, 2013a; Scollie et al., 2005) to prevent hardware
saturation, rather than an empirical preference optimum. This contrasts
with well-supported heuristic targets like the 3.0:1 Compression Ratio
bound (Stage 12), which is directly grounded in extensive empirical
psychoacoustic data (Souza, 2002; Souza et al., 2006). However, to
enforce this bound safely during unconstrained optimization, Open-NL
applies the 3.0:1 constraint both as a soft objective penalty
($P_(c r)$) to guide the optimizer, and as a strict post-optimization
hard clamp. This dual constraint structure ensures that the raw drive to
maximize SII in profound profiles never violates empirical
psychoacoustic limits. For reverse-slope losses (A2), the SD-LFP
constraint successfully limits low-frequency over-amplification,
demonstrating how integrated constraints stabilize complex objective
landscapes.

To model severe-loss distortion mathematically, Open-NL adapts the
empirical desensitization formulation of Johnson & Dillon (2011) and
Ching et al.~(1998). Crucially, the engine isolates the pure
sensorineural component ($T_(h l) = max \( 0 \, T'_i - J_i \)$) by
subtracting the air-bone gap ($J_i$), and corrects a historical flaw in
ANSI S3.5 implementations by restricting the internal cochlear noise
floor calculation strictly to sensorineural loss
($X'_i = X_i + max \( 0 \, T'_i - J_i \)$), preventing conductive
attenuation from falsely inflating internal noise. While the rigid
clinical formula ($K'_(c o m p l e t e) = \( K_i^p + m^p \)^(1 \/ p)$)
introduces non-differentiable step boundaries that stall simplex
optimizers, Open-NL's optimizer evaluates intermediate solutions against
a continuous mathematical relaxation: where $K_i$ is raw audibility and
$m$ is the maximum asymptotic audibility limit directly extracted from
Ching et al.~(1998). This continuous relaxation permits smooth gradient
descent. While the maximum discrepancy between the relaxation and the
full piecewise function
($max \| K'_(s m o o t h e d) - K'_(c o m p l e t e) \|$) reaches up to
0.20 raw band audibility units at intermediate thresholds
($T_(h l) approx 67$ dB HL), finalized targets are rigorously
post-scored against the rigid piecewise $K'_(c o m p l e t e)$
formulation to ensure objective integrity (detailed fully in Stage 7 and
Stage 12 of the Supplementary Material).

=== C. Clinical Validation Protocols and Falsifiable Predictions
<c.-clinical-validation-protocols-and-falsifiable-predictions>
While synthetic evaluations verify mathematical behavior, translating
Open-NL to clinical application mandates three non-negotiable validation
hard gates to address the metric tautology and binaural summation
boundaries: 1. #strong[Real-Ear Measurement (REM) Verification];:
Because physical ear-canal acoustics, leakage, and transducer roll-off
decouple eardrum SPL from simulated targets (Dao et al., 2021), REM
verification is mandatory. Empirical evidence robustly demonstrates that
REM-verified fittings significantly outperform unverified first-fits on
speech recognition and patient preference (Valente et al., 2018;
Almufarrij, Dillon, & Munro, 2021). 2. #strong[Individualized Broadband
Loudness-Tolerance Safety Gates (trueLOUDNESS)];: Because monaural
loudness models underestimate perceived binaural broadband loudness in a
substantial cohort of impaired listeners (Section II.A), clinical
translation cannot rely on audiogram-derived monaural ceilings. Prior to
any behavioral testing, individualized binaural broadband loudness
scaling (e.g., trueLOUDNESS procedures; Oetting et al., 2016, 2017) or
rigorous Uncomfortable Loudness Level (UCL) verification must be
administered to establish subject-specific safety caps and prevent
acoustic trauma. 3. #strong[Independent Waveform-Level Speech
Recognition Benchmarks];: To overcome the metric tautology of SII
scoring, aided performance must be benchmarked using independent
speech-in-noise testing (e.g., matrix sentence tests or WIN/HINT)
alongside computational HASPI/HASQI modeling (Kates & Arehart, 2022).
These evaluations must reference conservative clinical controls (such as
DSL v5.0 or NAL-NL2), which empirical literature robustly favors in the
50--80 dB HL range (Mueller, 2005; Engler, Digeser, & Hoppe, 2026).

Beyond safety protocols, this framework yields a concrete, falsifiable
clinical prediction: because Open-NL's uncalibrated A4 and A5
high-frequency targets exceed NAL-NL2 by roughly 11 dB at 4000 Hz, they
push far beyond historical comfort boundaries (Keidser et al., 2012a;
Denk et al., 2025). We offer the following operational hypothesis: If
adult listeners with A4 or A5 audiometric profiles are fitted with
real-ear verified Open-NL targets, \>80% will exhibit immediate
categorical loudness rejection---operationally defined as a rating of 6
("Loud") or 7 ("Uncomfortably Loud") on the 7-point Categorical Loudness
Scaling (CLS) procedure (ISO 16832)---when presented with continuous
broadband speech (e.g., ISTS) at 65 and 80 dB SPL, relative to a matched
NAL-NL2 baseline. Empirically quantifying this rejection threshold will
provide the ground-truth data required to constrain distortion-aware
objective functions in future stochastic calibrations.

== IV. CONCLUSION
<iv.-conclusion>
Open-NL provides a transparent, modular computational testbed for
modeling, ablating, and evaluating WDRC prescriptive heuristics natively
within R. By coupling an explicitly defined mathematical pipeline with
an embedded C++ specific-loudness engine, the package enables
researchers to systematically inspect the trade-offs between audibility
and physiological loudness without relying on closed-source clinical
software. As the framework evolves, it provides the computational
substrate needed to evaluate emerging multi-profile rationales such as
NAL-NL3 (Kitterick, Zakis, & Edwards, 2026a) and to integrate
individualized broadband loudness summation metrics (Denk et al., 2025).

== ACKNOWLEDGMENTS
<acknowledgments>
The author wishes to thank the original developers of the R-project
ecosystem and the open-source contributors whose foundational work
enabled the creation of this computational toolkit.

== AUTHOR DECLARATIONS
<author-declarations>
=== Conflict of Interest
<conflict-of-interest>
The author declares no conflicts of interest.

=== Ethics Approval
<ethics-approval>
The author declares that no animal subjects or human participants were
involved in the development, theoretical simulation, or mathematical
validation presented in this research.

== DATA AVAILABILITY
<data-availability>
The source code for the `SII` package, the Open-NL prescriptive
algorithm, complete parameter specifications, and all associated
datasets and benchmarking scripts are openly available in the public
repository at https:\/\/github.com/r-gregmisc/SII (v1.2.4; Git commit
`b2b5ce0`; Archival DOI:
#link("https://doi.org/10.5281/zenodo.14963842")[10.5281/zenodo.14963842];;
License: GPL-3.0). Standalone replication scripts generating all
figures, tables, and sensitivity sweeps reported in this manuscript are
located in the `reproducibility_scripts/` directory.

== VI. REFERENCES
<vi.-references>
Almufarrij, I., Dillon, H., & Munro, K. J. (2021). Does probe-tube
verification of real-ear hearing aid amplification characteristics
improve outcomes in adult hearing aid users? A systematic review and
meta-analysis. #emph[Trends in Hearing];, 25.

Baer, T., Moore, B. C., & Kluk, K. (2002). Effects of low pass filtering
on the intelligibility of speech in quiet for people with and without
dead regions at high frequencies. #emph[The Journal of the Acoustical
Society of America];, 112(3), 1133-1144.

Byrne, D., Parkinson, A., & Newall, P. (1990). Hearing aid gain and
frequency response requirements for the severely/profoundly hearing
impaired. #emph[Ear and Hearing];, 11(1), 40-49.

Ching, T. Y., Dillon, H., & Byrne, D. (1998). Speech recognition of
hearing-impaired listeners: Predictions from audibility and the limited
role of high-frequency amplification. #emph[The Journal of the
Acoustical Society of America];, 103(2), 1128-1140.

Ching, T. Y., Dillon, H., Katsch, R., & Byrne, D. (2001). Maximizing
effective audibility in hearing aid fitting. #emph[Ear and hearing];,
22(3), 212-224.

Cox, R. M., Alexander, G. C., Johnson, J., & Rivera, I. (2011). Cochlear
dead regions in typical hearing aid candidates: prevalence and
implications for use of high-frequency speech cues. #emph[Ear and
Hearing];, 32(3), 339-348.

Cox, R. M., Johnson, J. A., & Alexander, G. C. (2012). Implications of
high-frequency cochlear dead regions for fitting hearing aids to adults
with mild to moderately severe hearing loss. #emph[Ear and Hearing];,
33(5), 573-587.

Dao, A., Folkeard, P., Baker, S., Pumford, J., & Scollie, S. (2021).
Fit-to-Targets and Aided Speech Intelligibility Index Values for Hearing
Aids Fitted to the DSL V5-Adult Prescription. #emph[Journal of the
American Academy of Audiology];, 32(2), 90-98.

Denk, F., Oetting, D., Latzel, M., Bonsel, H., & Husstedt, H. (2025).
Prevalence of excess binaural broadband loudness summation in the
hearing-impaired population and implications for hearing aid gain
targets. #emph[PLOS ONE];, 20(3), e0319236.
https:\/\/doi.org/10.1371/journal.pone.0319236

Dillon, H. (2012). #emph[Hearing Aids] (2nd ed.). Boomerang Press.

Engler, M., Digeser, F., & Hoppe, U. (2026). Speech recognition and
real-ear-measured amplification in hearing-aid users with various grades
of hearing loss. #emph[International Journal of Audiology];, 65(7),
834--845. https:\/\/doi.org/10.1080/14992027.2024.2426009

Herzke, T., Kayser, H., Loshaj, F., Grimm, G., & Hohmann, V. (2017).
OpenMHA---An open-source software platform for hearing aid research.
#emph[Trends in Hearing];, 21, 2331216517743250.

Johnson, E. E. (2013a). Prescriptive Amplification Recommendations for
Hearing Losses with a Conductive Component and Their Impact on the
Required Maximum Power Output: An Update with Accompanying Clinical
Explanation. #emph[Journal of the American Academy of Audiology];,
24(6), 452-460.

Johnson, E. E., & Dillon, H. (2011). A comparison of gain for adults
from generic hearing aid prescriptive methods: Impacts on predicted
loudness, frequency bandwidth, and speech intelligibility. #emph[Journal
of the American Academy of Audiology];, 22(7), 441-459.

Kates, J. M., & Arehart, K. H. (2022). An overview of the HASPI and
HASQI metrics for predicting speech intelligibility and speech quality
for normal hearing, hearing loss, and hearing aids. #emph[Hearing
Research];, 424, 108593.

Keidser, G., Dillon, H., Dyrlund, O., Carter, L., & Hartley, D. (2007).
Preferred Compression Ratios in the Low and High Frequencies by the
Moderately Severe to Severe-Profound Population. #emph[Journal of the
American Academy of Audiology];, 18(1), 17-33.

Keidser, G., Dillon, H., Carter, L., & O'Brien, A. (2012a). NAL-NL2
empirical adjustments. #emph[Trends in Amplification];, 16(4), 211-223.

Kitterick, P. T., Zakis, J. A., & Edwards, B. (2026a). Evolving the
philosophy: From the NAL rule to NAL-NL3. Advance online publication.
1-10. https:\/\/doi.org/10.1080/14992027.2026.2690236

Kitterick, P. T., Zakis, J. A., & Edwards, B. (2026b). The NAL-NL3
comfort-in-noise module. #emph[International Journal of Audiology];. In
press.

Lybarger, S. F. (1944). #emph[US Patent No.~2,357,838];. Washington, DC:
U.S. Patent and Trademark Office.

Majdak, P., Hollomey, C., & Baumgartner, R. (2022). AMT 1.x: A toolbox
for reproducible research in auditory modeling. #emph[Acta Acustica];,
6, 19. https:\/\/doi.org/10.1051/aacus/2022011

Margolis, R. H., Hornsby, B. W. Y., Saly, G. L., & Wilson, R. H. (2025).
Predicted and measured word-recognition scores unmask distortion in the
impaired auditory system. #emph[The Journal of the Acoustical Society of
America];, 157(2), 555--568. https:\/\/doi.org/10.1121/10.0036461

Moore, B. C. (2001). Dead regions in the cochlea: Diagnosis, perceptual
consequences, and implications for the fitting of hearing aids.
#emph[Trends in Amplification];, 5(1), 1-34.

Moore, B. C. J., & Glasberg, B. R. (2004). A revised model of loudness
perception applied to cochlear hearing loss. #emph[Hearing Research];,
188(1-2), 70-88.

Moore, B. C., Glasberg, B. R., & Stone, M. A. (2010). Development of a
new method for deriving initial fittings for hearing aids with
multi-channel compression: CAMEQ2-HF. #emph[International Journal of
Audiology];, 49(3), 216-227.

Moore, B. C., Gibbs, A., Onions, G., & Glasberg, B. R. (2014).
Measurement and modeling of binaural loudness summation for
hearing-impaired listeners. #emph[The Journal of the Acoustical Society
of America];, 136(5), 2697-2708.

Moualed, D., Humphries, J., & Ramsden, J. D. (2018). Cochlear dead
regions: Using the Threshold Equalising Noise (TEN) test to improve the
assessment of potential cochlear implant candidates---The Oxford
experience. #emph[Clinical Otolaryngology];, 43(1), 384-387.

Mueller, H. G. (2005). Fitting hearing aids to adults using prescriptive
methods: An evidence-based review of effectiveness. #emph[Journal of the
American Academy of Audiology];, 16(7), 448-460.

Oetting, D., Hohmann, V., Appell, J. E., Kollmeier, B., & Ewert, S. D.
(2016). Spectral and binaural loudness summation for hearing-impaired
listeners. #emph[Hearing Research];, 335, 179-192.

Oetting, D., Hohmann, V., Appell, J. E., Kollmeier, B., & Ewert, S. D.
(2017). Restoring perceived loudness for listeners with hearing loss.
#emph[Ear and Hearing];, 38(1), 74-83.

Pepler, A., Lewis, K., & Munro, K. J. (2015). Adult hearing-aid users
with cochlear dead regions restricted to high frequencies: implications
for amplification. #emph[International Journal of Audiology];, 54(5),
297-306.

Pieper, I., Mauermann, M., Kollmeier, B., & Ewert, S. D. (2021). Toward
an Individual Binaural Loudness Model for Hearing Aid Fitting and
Development. #emph[Frontiers in Psychology];, 12, 638662.

Scollie, S., Seewald, R., Cornelisse, L., Moodie, S., Bagatto, M.,
Laurnagaray, D., Beaulac, S., & Pumford, J. (2005). The Desired
Sensation Level multistage input/output algorithm. #emph[Trends in
Amplification];, 9(4), 159-197.

Souza, P. E. (2002). Effects of compression on speech acoustics,
intelligibility, and sound quality. #emph[Trends in Amplification];,
6(4), 131-165.

Souza, P. E., Jenstad, L. M., & Boike, K. T. (2006). Measuring the
acoustic effects of compression amplification on speech in noise.
#emph[The Journal of the Acoustical Society of America];, 119(1), 41-44.
https:\/\/doi.org/10.1121/1.2108861

Souza, P., Hoover, E., Blackburn, M., & Gallun, F. (2018). The
characteristics of adults with severe hearing loss. #emph[Journal of the
American Academy of Audiology];, 29(8), 764-779.

Valente, M., Oeding, K., Brockmeyer, A., Smith, S., & Kallogjeri, D.
(2018). Differences in word and phoneme recognition in quiet, sentence
recognition in noise, and subjective outcomes between manufacturer
first-fit and hearing aids programmed to NAL-NL2 using real-ear
measures. #emph[Journal of the American Academy of Audiology];, 29(8),
706-721.

van Beurden, M., Boymans, M., van Geleuken, M., et al.~(2021). Uni- And
Bilateral Spectral Loudness Summation and Binaural Loudness Summation
With Loudness Matching and Categorical Loudness Scaling.
#emph[International Journal of Audiology];, 60(2), 108-118.

Vestergaard, M. D. (2003). Dead regions in the cochlea: Implications for
speech recognition and applicability of articulation index theory.
#emph[International Journal of Audiology];, 42(5), 249-261.

= Supplementary Material: Open-NL Algorithmic Pipeline and Complete Parameter Specification
<supplementary-material-open-nl-algorithmic-pipeline-and-complete-parameter-specification>
This supplementary document provides the exact mathematical
formulations, closed-form piecewise functions, and complete numerical
parameter specifications governing the twelve internal processing stages
of the Open-NL algorithmic cascade.

== S.I. The Twelve-Stage Execution Cascade
<s.i.-the-twelve-stage-execution-cascade>
Open-NL operates as a multi-stage parameterized shape generator. Rather
than relying on static compiled lookup tables, Open-NL calculates target
insertion gains dynamically through a series of twelve explicitly
defined, cascaded mathematical modules. Each step in the gain derivation
process is exposed natively in R, available for researchers to inspect,
modify, and tune.

#emph[Terminology Note:] Throughout this framework, the algorithm
utilizes two distinct discomfort predictors for different theoretical
purposes: an HL-domain "LDL" (Loudness Discomfort Level) predictor used
for estimating clinical audiometric dynamic range (Stage 8), and an
SPL-domain "UCL" (Uncomfortable Loudness Level) predictor for
establishing physical device saturation limits (Stage 11). A visual
flowchart mapping each predictor to its downstream algorithm function is
provided in Diagram 1.

```text
===========================================================================
                  DIAGRAM 1. Open-NL Discomfort Predictors
===========================================================================

       [ CLINICAL DYNAMIC RANGE ]          [ PHYSICAL DEVICE LIMITS ]
                   |                                   |
                   v                                   v
             LDL Predictor                       UCL Predictor
                (dB HL)                            (dB SPL)
                   |                                   |
    100 + max(0, HTL - 40)*0.5 + Loss_cond    105 + 0.5 * max(0, HTL - 20)
                   |                                   |
                   v                                   v
        Dynamic Range "Squeeze"            Maximum Power Output (MPO) 
      (Insertion Gain Attenuation)       (Saturation Limit & CR Calc)

===========================================================================
```

The twelve modules operate in a strictly defined cascaded execution
order to prevent unintended interactions between additive boosters and
soft limiters:

+ #strong[Stage 1: Conductive Component Separation & Dynamic Range
  Baseline] (Section II.D)
+ #strong[Stage 2: Decoupled Half-Gain Base Anchor Calculation] (Section
  II.E)
+ #strong[Stage 3: Experience-Level Shaping & Log-Frequency
  $C_(v a l s)$ Interpolation] (Section II.F)
+ #strong[Stage 4: Reverse-Slope Low-Frequency Attenuation Floor]
  (Section II.G)
+ #strong[Stage 5: Slope-Dependent Low-Frequency Penalty (SD-LFP) with
  Profound HF Bypass] (Section II.H)
+ #strong[Stage 6: Severe-Loss Audibility Booster] (Section II.I)
+ #strong[Stage 7: Soft-Compression High-Frequency Desensitization]
  (Section II.J)
+ #strong[Stage 8: Dynamic Range Mapping (LDL Squeeze)] (Section II.K)
+ #strong[Stage 9: Transducer Bandwidth Roll-off] (Section II.L)
+ #strong[Stage 10: Multi-Channel WDRC Mapping, Input/Output Pivot, and
  Demographic Adjustments] (Section II.M)
+ #strong[Stage 11: Acoustic Venting, Coupling Loss, and Receiver
  Saturation Limits] (Section II.N)
+ #strong[Stage 12: Embedded Nelder-Mead Simplex Optimization &
  Physiological Loudness Ceilings] (Section II.O)

#horizontalrule

== S.I.1. Stage 1: Conductive Component Separation & Dynamic Range Baseline
<s.i.1.-stage-1-conductive-component-separation-dynamic-range-baseline>
The algorithm first decomposes total hearing threshold levels
($upright("HTL")$) into their physiological constituents: the
sensorineural threshold ($upright("HTL")_(s n)$) and the conductive
component ($upright("Loss")_(c o n d)$, corresponding to the air-bone
gap, ABG):

To ensure that equal-loudness reshaping penalties apply only to
sensorineural pathology, the algorithm computes a frequency-specific
sensorineural ratio $R_(s n) \( f \)$:

Pure conductive losses ($upright("Loss")_(c o n d) = upright("HTL")$)
have normal outer and inner hair cell functioning and intact basilar
membrane mechanics; thus, $R_(s n) = 0$, bypassing cochlear recruitment
and equal-loudness correction arrays.

#horizontalrule

== S.I.2. Stage 2: Decoupled Half-Gain Base Anchor Calculation
<s.i.2.-stage-2-decoupled-half-gain-base-anchor-calculation>
The foundational WDRC anchor for average conversational speech (65 dB
SPL) is derived using a frequency-specific adaptation of the half-gain
rule (Lybarger, 1944). Unlike linear prescriptions that anchor to a
broadband Pure Tone Average (PTA), this anchor is decoupled
frequency-by-frequency:

where $alpha = 0.46$ is the nominal half-gain multiplier (loosely
derived from Byrne & Dillon, 1986), and $C_(i n t e r p) \( f \)$ is the
frequency-shaping correction array derived in Stage 3.

#horizontalrule

== S.I.3. Stage 3: Experience-Level Shaping & Log-Frequency $C_(v a l s)$ Interpolation
<s.i.3.-stage-3-experience-level-shaping-log-frequency-c_vals-interpolation>
To account for listener acclimatization and preferred listening levels
(Keidser et al., 2012a), Open-NL modulates the frequency-shaping array
$C_(i n t e r p)$ across eight discrete anchor frequencies:

The discrete shaping vectors $upright(bold(C))$ are defined as: -
#strong[Experienced Users] (standard baseline): - #strong[New Users]
(nominal $- 3$ dB reduction to combat occlusion and sharpness): -
#strong[Power Users] (prioritizes raw audibility over acoustic comfort):

For any calculation frequency $f$, $C_(i n t e r p) \( f \)$ is
evaluated via piecewise log-linear interpolation across
$upright(bold(f))_c$ and scaled by the sensorineural proportion
$R_(s n) \( f \)$:

#horizontalrule

== S.I.4. Stage 4: Reverse-Slope Low-Frequency Attenuation Floor
<s.i.4.-stage-4-reverse-slope-low-frequency-attenuation-floor>
For reverse-slope configurations (where low frequencies are
significantly worse than high frequencies), attempting to fully restore
low-frequency audibility risks upward spread of masking, where
high-energy low-frequency vowels mask low-energy high-frequency
consonants. The algorithm calculates the low-to-high sensorineural
threshold difference:

where $overline(upright("HTL"))_(s n \, lt.eq 500)$ is the mean
threshold across $f lt.eq 500$ Hz, and
$overline(upright("HTL"))_(s n \, gt.eq 2000)$ is the mean threshold
across $f gt.eq 2000$ Hz. If $upright("Diff")_(r s) > 15$ dB, a
transition factor $R S_(f a c t o r) in \[ 0 \, 1 \]$ is computed:

A log-linear low-frequency taper $W_(L F) \( f \)$ is applied below 1000
Hz:

Across octave bands, $W_(L F) \( f \)$ evaluates to $1.0$ at 250 Hz,
$0.5$ at 500 Hz, and $0.0$ at $f gt.eq 1000$ Hz. The frequency-shaping
array is then dynamically flattened toward a $- 10$ dB floor:

#horizontalrule

== S.I.5. Stage 5: Slope-Dependent Low-Frequency Penalty (SD-LFP) with Profound HF Bypass
<s.i.5.-stage-5-slope-dependent-low-frequency-penalty-sd-lfp-with-profound-hf-bypass>
For sloping high-frequency losses, applying excessive low-frequency gain
causes normal low frequencies to dominate broadband loudness. Open-NL
computes the high-frequency slope:

To operationalize the empirical findings of Byrne, Parkinson, and Newall
(1990)---who showed that listeners with high-frequency losses exceeding
70--95 dB HL require low-frequency speech cues---Open-NL incorporates a
#strong[Profound High-Frequency Bypass];:

The low-frequency penalty is scaled over a 20 dB slope window, capped at
15 dB:

The penalty is then tapered below 1000 Hz using $W_(L F) \( f \)$:

The resulting baseline target at 65 dB SPL is:

=== Ablation of SD-LFP Constraints
<ablation-of-sd-lfp-constraints>
Table S1 provides the reference audiometric profiles (A1--A7, Johnson &
Dillon, 2011). Table S2 demonstrates the mechanical impact of the SD-LFP
constraint on the initial heuristic seeds.

#strong[TABLE S1. Reference Audiometric Profiles (Adapted from Johnson &
Dillon, 2011).] #emph[Thresholds are in dB HL. Profiles A1--A5 are
purely sensorineural. A6 is mixed (30 dB ABG). A7 is conductive (50 dB
ABG).]

#figure(
  align(center)[#table(
    columns: (9.3%, 9.3%, 11.63%, 11.63%, 11.63%, 11.63%, 11.63%, 11.63%, 11.63%),
    align: (left,left,center,center,center,center,center,center,center,),
    table.header([Profile], [Type], [250 Hz], [500 Hz], [1000 Hz], [2000
      Hz], [4000 Hz], [8000 Hz], [ABG],),
    table.hline(),
    [#strong[A1];], [Mild], [15], [20], [30], [40], [50], [60], [0 dB],
    [#strong[A2];], [Reverse
    slope], [60], [50], [40], [30], [20], [15], [0 dB],
    [#strong[A3];], [Moderately
    sloping], [10], [20], [40], [50], [55], [60], [0 dB],
    [#strong[A4];], [Severe], [0], [0], [10], [40], [70], [80], [0 dB],
    [#strong[A5];], [Profound], [10], [10], [20], [60], [80], [100], [0
    dB],
    [#strong[A6];], [Mixed], [50], [55], [60], [65], [75], [80], [30
    dB],
    [#strong[A7];], [Conductive], [50], [50], [50], [50], [50], [50], [50
    dB],
  )]
  , kind: table
  )

#strong[TABLE S2. Ablation of SD-LFP Constraints on Optimizer Seed (65
dB SPL Input).]

#figure(
  align(center)[#table(
    columns: (20%, 20%, 20%, 20%, 20%),
    align: (auto,auto,auto,auto,auto,),
    table.header([Profile], [Unconstrained Seed SII], [Unconstrained
      Seed Sones], [SD-LFP Seed SII], [SD-LFP Seed Sones],),
    table.hline(),
    [A1 (Flat mod)], [0.86], [7.2], [0.86], [7.2],
    [A2 (Reverse)], [0.88], [6.3], [0.88], [6.0],
    [A3 (Mod sloping)], [0.79], [6.8], [0.79], [6.8],
    [A4 (Severe)], [0.81], [6.9], [0.81], [6.9],
    [A5 (Profound)], [0.68], [7.1], [0.68], [6.0],
    [A6 (Mixed)], [0.82], [3.0], [0.82], [3.0],
    [A7 (Conductive)], [0.97], [1.0], [0.97], [1.0],
  )]
  , kind: table
  )

#horizontalrule

== S.I.6. Stage 6: Severe-Loss Audibility Booster
<s.i.6.-stage-6-severe-loss-audibility-booster>
To overcome inner hair cell loss in severe impairments, an opt-in,
bounded #strong[Severe-Loss Booster] can be applied:

where $B_(e n) in { 0 \, 1 }$ (default: 0, disabled), and
$T_(o n s e t) = 70$ dB HL (conservative default) or $60$ dB HL
(aggressive ablation mode). The intermediate target is:

#horizontalrule

== S.I.7. Stage 7: Soft-Compression High-Frequency Desensitization
<s.i.7.-stage-7-soft-compression-high-frequency-desensitization>
To prevent unconstrained audibility maximization from prescribing
intolerable high-frequency gain in steeply sloping losses, Open-NL
applies a dynamic soft-compression envelope ($L_(g a i n)$):

#emph[(Note: For patients in "Moderate" or "High" distortion categories,
$L_(g a i n)$ is reduced by 10 dB).]

Excess gain above this dynamic limit is:

The sloping factor $S_(f a c t o r) \( f \)$ relative to the best
low-frequency threshold
($upright("HTL")_(b e s t l o w) = min_(f' lt.eq 1000) upright("HTL")_(s n) \( f' \)$)
and the high-frequency fade-in weight $W_(h f) \( f \)$ are:

Applying 2:1 soft compression to the excess yields:

If explicit cochlear dead regions ($f_(e \_ h f)$, $f_(e \_ l f)$) or
distortion categories (Margolis et al., 2025) are defined, steep
parametric roll-offs are applied:

#horizontalrule

== S.I.8. Stage 8: Dynamic Range Mapping (LDL Squeeze)
<s.i.8.-stage-8-dynamic-range-mapping-ldl-squeeze>
To accommodate reduced clinical dynamic ranges (DSL v5.0 philosophy;
Scollie et al., 2005), Open-NL predicts an HL-domain Loudness Discomfort
Level:

When measured $upright("LDL")_(m e a s) \( f \)$ is lower than
predicted, the dynamic range discrepancy $Delta_(L D L) \( f \)$ is
quantified:

Target gain is attenuated by 0.2 dB per dB of dynamic range squeeze:

Simultaneously, the baseline compression ratio increases by $+ 0.02$ per
dB of squeeze (Stage 10).

#horizontalrule

== S.I.9. Stage 9: Transducer Bandwidth Roll-off
<s.i.9.-stage-9-transducer-bandwidth-roll-off>
Acoustic transducers physically struggle to reproduce frequencies at the
extremes of the spectrum ($lt.eq 250$ Hz and $gt.eq 6000$ Hz), where
massive gain leads to distortion and feedback. Open-NL applies a
continuous fractional bandwidth roll-off multiplier $M_(b w) \( f \)$
defined over seven anchor frequencies:

The closed-form continuous multiplier is obtained via piecewise
log-linear interpolation:

#horizontalrule

== S.I.10. Stage 10: Multi-Channel WDRC Mapping, Input/Output Pivot, and Demographic Adjustments
<s.i.10.-stage-10-multi-channel-wdrc-mapping-inputoutput-pivot-and-demographic-adjustments>
Target gain at arbitrary overall input level $L_(i n)$ (e.g., 50, 65, 80
dB SPL) is computed using a multi-channel wide dynamic range compression
architecture pivoted around the Long-Term Average Speech Spectrum
(LTASS).

+ #strong[Speech Spectrum Pivot];: Let $P \( f \)$ be the critical-band
  normal speech level at 65 dB SPL overall. The band-specific input
  level is:

+ #strong[Dynamic Compression Ratio Calculation];: For severe loss
  ($upright("HTL")_(s n) > 65$ dB HL), compression reduces back toward
  linear to preserve the temporal speech envelope (Keidser et al.,
  2007): $upright("CR")_(l o u d) \( f \)$ is clamped between $1.0$ and
  a maximum
  $upright("CR")_(m a x) \( f \) = 1.5 + 0.9 dot.op W_(f r e q) \( f \)$
  (further relaxed for age $> 60$). In Comfort in Noise (CIN) mode,
  $upright("CR")_(l o u d)$ is clamped to $lt.eq 1.5$.

  #emph[(Note on Evidentiary Asymmetry: The 1.5:1 CIN clamp is an
  asserted engineering heuristic inspired by NAL-NL3 to curb listening
  fatigue in noise, lacking direct empirical derivation. In contrast,
  the global upper ceiling on compression ratios ($lt.eq 3.0 : 1$) is
  directly supported by extensive psychoacoustic literature \[Souza,
  2002; Souza et al., 2006\], which demonstrates that compression ratios
  exceeding 3.0:1 cause severe temporal envelope flattening and acoustic
  contrast degradation).]

+ #strong[Variable Compression Threshold (CT)];: Overall CT
  ($upright("CT")_(o v e r a l l)$) scales from 30 to 45 dB SPL as a
  function of threshold. The band-level threshold is
  $upright("CT")_(b a n d) \( f \) = P \( f \) + \( upright("CT")_(o v e r a l l) - 65 \)$
  (reduced by 10 dB in CIN mode).

+ #strong[Piecewise Linear-Compressive Spline];: Gain at the compression
  threshold is: The level-dependent WDRC target gain is:

+ #strong[Demographic Adjustments];: where $Delta_(g e n d e r) = - 1.5$
  dB (female), $Delta_(c o n f i g) = + 3.0$ dB (unilateral), and
  $Delta_(e x p) = - min (6.0 \, 0.3 dot.op max (0 \, upright("PTA")_(500 \, 1 k \, 2 k) - 40))$
  for new users.

#strong[TABLE S3. Effective Compression Ratios (50 to 80 dB SPL Inputs)
across A1-A7 Audiograms.] #emph[Note: Dashes (-) indicate frequency
regions where prescribed gain is exactly 0 dB for both 50 and 80 dB SPL
inputs (linear amplification, CR = 1.0). Note that these values
represent the emergent multi-level input/output ratios measured
dynamically between 50 and 80 dB SPL inputs, rather than the prescribed
static channel CRs calculated internally in Stage 10. To strictly
enforce the 3.0:1 maximum bound, Open-NL applies dual constraints: a
soft objective penalty ($P_(c r)$) during optimization, followed by a
strict hard clamp, ensuring that pure intelligibility maximization never
violates empirical psychoacoustic limits.]

#figure(
  align(center)[#table(
    columns: (12.86%, 12.86%, 11.43%, 11.43%, 12.86%, 12.86%, 12.86%, 12.86%),
    align: (auto,auto,auto,auto,auto,auto,auto,auto,),
    table.header([Profile], [Formula], [250 Hz], [500 Hz], [1000
      Hz], [2000 Hz], [4000 Hz], [8000 Hz],),
    table.hline(),
    [A1], [NAL-NL2], [1.01], [1.07], [1.69], [2.27], [2.63], [2.17],
    [A1], [Open-NL], [1.04], [\-], [1.42], [1.36], [1.66], [1.66],
    [A2], [NAL-NL2], [2.11], [2.36], [2.07], [1.86], [1.40], [1.28],
    [A2], [Open-NL], [1.50], [1.78], [2.10], [1.73], [1.18], [\-],
    [A3], [NAL-NL2], [\-], [1.10], [1.88], [2.48], [2.70], [2.19],
    [A3], [Open-NL], [\-], [1.03], [1.71], [1.59], [3.00], [3.00],
    [A4], [NAL-NL2], [\-], [\-], [1.12], [2.17], [2.22], [1.88],
    [A4], [Open-NL], [\-], [\-], [\-], [1.45], [2.51], [1.50],
    [A5], [NAL-NL2], [\-], [\-], [1.59], [2.11], [1.99], [1.79],
    [A5], [Open-NL], [\-], [\-], [\-], [1.83], [1.34], [1.10],
    [A6], [NAL-NL2], [1.32], [1.42], [1.61], [2.00], [2.24], [1.91],
    [A6], [Open-NL], [1.16], [1.27], [1.38], [1.47], [1.64], [1.71],
    [A7], [NAL-NL2], [1.00], [1.00], [1.00], [1.00], [1.00], [1.00],
    [A7], [Open-NL], [1.00], [1.00], [1.00], [1.00], [1.00], [1.00],
  )]
  , kind: table
  )

#horizontalrule

== S.I.11. Stage 11: Acoustic Venting, Coupling Loss, and Receiver Saturation Limits
<s.i.11.-stage-11-acoustic-venting-coupling-loss-and-receiver-saturation-limits>
Real-Ear Aided Responses (REAR) are heavily influenced by acoustic
coupling. Low-frequency leakage is modeled by log-frequency
interpolation over anchor frequencies
$upright(bold(f))_(v e n t) = \[ 250 \, 500 \, 1000 \, 2000 \, 4000 \, 8000 \] upright(" Hz")$:

where $upright(bold(v))_c$ is the coupling-specific attenuation vector
defined in Table S4.

#strong[TABLE S4. Acoustic Coupling Real-Ear Insertion Loss Vectors
($upright(bold(v))_c$, in dB).]

#figure(
  align(center)[#table(
    columns: (11.76%, 14.71%, 14.71%, 14.71%, 14.71%, 14.71%, 14.71%),
    align: (left,center,center,center,center,center,center,),
    table.header([Coupling Configuration], [250 Hz], [500 Hz], [1000
      Hz], [2000 Hz], [4000 Hz], [8000 Hz],),
    table.hline(),
    [Custom Occluded], [0], [0], [0], [0], [0], [0],
    [Open Dome], [-35], [-28], [-15], [-2], [0], [0],
    [Tulip Dome], [-25], [-18], [-5], [0], [0], [0],
    [Double Dome], [-20], [-10], [0], [0], [0], [0],
    [Vent (1mm Solid)], [-3], [-1], [0], [0], [0], [0],
    [Vent (2mm Solid)], [-8], [-2], [0], [0], [0], [0],
    [Vent (3mm Solid)], [-12], [-4], [0], [0], [0], [0],
    [Vent (1mm Hollow)], [-12], [-3], [0], [0], [0], [0],
    [Vent (2mm Hollow)], [-22], [-12], [-5], [-2], [0], [0],
    [Vent (3mm Hollow)], [-25], [-15], [-8], [-4], [0], [0],
  )]
  , kind: table
  )

Conductive air-bone gaps are restored linearly with a 75% fraction:
$G_(c o n d) \( f \) = 0.75 dot.op upright("Loss")_(c o n d) \( f \)$
#emph[(Note: This 75% restoration fraction is a pragmatic engineering
convention---adapted from clinical practice to prevent excessive output
demands and MPO clipping; Johnson, 2013a---without direct empirical
derivation from listener preference)];. To prevent active anti-phase
cancellation demands and comb filtering, insertion gain is floored at
$V_(l o s s) \( f \) - 10$ dB:

Hardware receiver limits (MPO/SSPL90) are established to avoid severe
saturation distortion:

#horizontalrule

== S.I.12. Stage 12: Embedded Nelder-Mead Simplex Optimization & Physiological Loudness Ceilings
<s.i.12.-stage-12-embedded-nelder-mead-simplex-optimization-physiological-loudness-ceilings>
When `optimize = TRUE`, Open-NL adjusts the heuristic targets by
minimizing an unconstrained multi-objective loss function via
Nelder-Mead simplex search (`stats::optim`).

=== Parameter Vector and Gain Formation
<parameter-vector-and-gain-formation>
The optimization parameter vector is
$bold(delta) = \[ delta_250 \, delta_500 \, delta_1000 \, delta_2000 \, delta_4000 \, delta_8000 \]^T in bb(R)^6$.
During evaluation, shifts are clamped:

Candidate insertion gains $upright(bold(G)) in \[ 0 \, 80 \]$ dB are
interpolated to calculation frequencies:

=== Loss Function Formulation
<loss-function-formulation>
The Nelder-Mead solver minimizes:

where $upright("SII")_(d e s e n s)$ is the desensitized Speech
Intelligibility Index calculated using the `johnson2011_smoothed`
transfer function.

=== Explicit Penalty Terms and Exact Weights ($lambda$)
<explicit-penalty-terms-and-exact-weights-lambda>
+ #strong[Anchor Penalty] ($lambda_(a n c h o r) = 0.1$):

+ #strong[Out-of-Bounds Penalty] ($lambda_(b o u n d s) = 1000.0$):

+ #strong[Physiological Loudness Ceiling Penalty]
  ($lambda_(l o u d) = 2000.0$): #emph[(Note: While gain-based penalties
  in this framework are squared to strongly penalize large deviations,
  the loudness penalty is explicitly linear. This is a deliberate
  choice: because sones inherently represent a compressive power-law
  transformation of physical acoustic energy, a linear penalty in the
  sone domain naturally exerts an exponentially growing restriction on
  the underlying insertion gain. Squaring the sone error introduces
  severe mathematical stiffness and destabilizes the simplex gradient.)]
  where $upright("Sones")_(M G 04)$ is the Moore & Glasberg (2004)
  specific-loudness integration computed via native C++. The dynamic
  U-shaped cap is interpolated across Pure Tone Average knots
  $upright(bold(P T A))_(k n o t s) = \[ 10 \, 32.5 \, 52.5 \, 72.5 \, 90 \]$
  dB HL from level-specific sone vectors:

  - $L_(i n) = 50$ dB SPL:
    $upright(bold(K))_50 = \[ 1.5 \, 1.0 \, 0.8 \, 1.2 \, 1.2 \]$ sones
  - $L_(i n) = 65$ dB SPL:
    $upright(bold(K))_65 = \[ 7.0 \, 4.5 \, 4.0 \, 6.5 \, 6.0 \]$ sones
  - $L_(i n) = 80$ dB SPL:
    $upright(bold(K))_80 = \[ 20.0 \, 12.0 \, 10.0 \, 15.0 \, 14.0 \]$
    sones where $upright("PTA")_(s n)$ is defined as the four-frequency
    pure-tone average of the sensorineural component at 500, 1000, 2000,
    and 4000 Hz. #emph[Profile Adjustments:]
  - Reverse-slope restriction ($L_(i n) gt.eq 75$ dB SPL and low-to-high
    threshold difference $> 10$ dB):
    $upright("Cap") = upright("Cap")_(b a s e) - 0.10 dot.op \( overline(upright("HTL"))_(lt.eq 500) - overline(upright("HTL"))_(gt.eq 4000) \)$.
  - Conductive air-bone gap adjustment:
    $upright("Cap") arrow.l upright("Cap") - 0.25 dot.op upright("PTA")_(A B G)$
    (if $L_(i n) gt.eq 75$ dB SPL) or
    $+ 0.10 dot.op upright("PTA")_(A B G)$ (if $L_(i n) < 75$ dB SPL).

+ #strong[Broadband SPL Saturation Ceiling Penalty]
  ($lambda_(s p l) = 2000.0$):

+ #strong[Spectral Roughness Penalty] ($lambda_(r o u g h) = 0.5$):

+ #strong[Inter-Level Order Monotonicity Penalty]
  ($lambda_(o r d e r) = 2000.0$): Enforces $G_50 gt.eq G_65$ and
  $G_80 lt.eq G_65$:

+ #strong[Compression Ratio Ceiling Penalty] ($lambda_(c r) = 200.0$):
  where
  $Delta_(m a x \, j) = 10.0 dot.op \( 1 - upright("ABG")_j \/ max \( 0.001 \, upright("HTL")_j \) \)$
  for soft speech, bounding emergent compression ratios safely below
  3.0:1 for sensorineural loss while enforcing linear amplification for
  conductive components. This 3.0:1 ceiling represents the
  best-supported parameter in the algorithm, firmly grounded in
  empirical psychoacoustic literature (Souza, 2002; Souza et al., 2006)
  demonstrating severe envelope flattening, loss of acoustic contrast,
  and speech-in-noise deficits for CRs $> 3.0 : 1$.

+ #strong[Air-Bone Gap Excursion Penalty] ($lambda_(a b g) = 1.0$):

=== Solver Controls and Convergence Tolerances
<solver-controls-and-convergence-tolerances>
- #strong[Algorithm];: Nelder-Mead Simplex via R's `stats::optim()`.
- #strong[Iteration Ceiling];: `control = list(maxit = 800)`.
- #strong[Convergence Tolerance];: Relative convergence tolerance
  `reltol = sqrt(.Machine$double.eps) \approx 1.49 \times 10^{-8}`.
- #strong[Initial Simplex Seeding];: Seeding incorporates an audibility
  projection
  $bold(delta)_(s t a r t) = min \( 20 \, max \( 0 \, upright("target_aided") - G_(h e u r i s t i c) \) \)$,
  where
  $upright("target_aided") = min \( upright("UCL") - 5 \, max \( L_(i n) \, upright("HTL") + 10 \) \)$.
  Soft inputs receive $+ 3$ dB shift; loud inputs receive
  $max \( - 10 \, bold(delta)_(s t a r t) - 5 \)$ dB shift.
- #strong[Multi-Start Strategy];: A 5-iteration multi-start routine
  (seeding the initial simplex with the NAL-R target and executing four
  additional randomized restarts with uniform random jitter
  $bold(delta)_(s t a r t) arrow.l bold(delta)_(s t a r t) + cal(U) \( - 5 \, + 5 \)$)
  is deployed to stabilize numerical convergence, though Nelder-Mead
  inherently lacks formal global convergence guarantees.

#horizontalrule

== References
<references>
Denk, F., Oetting, D., Latzel, M., Bonsel, H., & Husstedt, H. (2025).
Prevalence of excess binaural broadband loudness summation in the
hearing-impaired population and implications for hearing aid gain
targets. #emph[PLOS ONE];, 20(3), e0319236.
https:\/\/doi.org/10.1371/journal.pone.0319236

Engler, M., Digeser, F., & Hoppe, U. (2026). Speech recognition and
real-ear-measured amplification in hearing-aid users with various grades
of hearing loss. #emph[International Journal of Audiology];, 65(7),
834--845. https:\/\/doi.org/10.1080/14992027.2024.2426009

Kitterick, P. T., Zakis, J. A., & Edwards, B. (2026a). Evolving the
philosophy: From the NAL rule to NAL-NL3. Advance online publication.
1-10. https:\/\/doi.org/10.1080/14992027.2026.2690236

Kitterick, P. T., Zakis, J. A., & Edwards, B. (2026b). The NAL-NL3
comfort-in-noise module. #emph[International Journal of Audiology];. In
press.

Margolis, R. H., Hornsby, B. W. Y., Saly, G. L., & Wilson, R. H. (2025).
Predicted and measured word-recognition scores unmask distortion in the
impaired auditory system. #emph[The Journal of the Acoustical Society of
America];, 157(2), 555--568. https:\/\/doi.org/10.1121/10.0036461

Moore, B. C., & Glasberg, B. R. (2004). A revised model of loudness
perception applied to cochlear hearing loss. #emph[Hearing Research];,
188(1-2), 70-88.

Scollie, S., Seewald, R., Cornelisse, L., Moodie, S., Bagatto, M.,
Laurnagaray, D., Beaulac, S., & Pumford, J. (2005). The Desired
Sensation Level multistage input/output algorithm. #emph[Trends in
Amplification];, 9(4), 159-197.

Souza, P. E. (2002). Effects of compression on speech acoustics,
intelligibility, and sound quality. #emph[Trends in Amplification];,
6(4), 131-165.

Souza, P. E., Jenstad, L. M., & Boike, K. T. (2006). Measuring the
acoustic effects of compression amplification on speech in noise.
#emph[The Journal of the Acoustical Society of America];, 119(1), 41-44.
https:\/\/doi.org/10.1121/1.2108861
