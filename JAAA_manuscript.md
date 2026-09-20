---
title: "Loudness budget constraints on high-frequency amplification in precipitous
  hearing loss"
author: "Mark Shaver"
affiliation: Wichita State University, Department of Communication Sciences and Disorders,
  Wichita, KS, USA
output:
  pdf_document: default
  word_document:
    reference_docx: null
    pandoc_args: "--webtex"
bibliography: paper.bib
csl: https://raw.githubusercontent.com/citation-style-language/styles/master/chicago-author-date.csl
geometry: margin=1in
fontsize: 12pt
linestretch: 2
indent: true
header-includes:
  - \usepackage{indentfirst}
  - \usepackage{lineno}
---

\linenumbers

## Abstract

**Background:** In precipitous high-frequency hearing loss, achieving sufficient audibility in the high frequencies is notoriously difficult. Historically, this limitation has been attributed to the choice of prescriptive fitting rationale or inherent physiological damage. 

**Purpose:** This study proposes an alternative explanation based on loudness budget arithmetic: unamplified speech energy in the residual normal-hearing low frequencies inherently consumes the majority of the patient's acceptable loudness budget, reducing the available capacity for the profoundly impaired high frequencies to achieve audibility.

**Research Design:** A computational modeling study using the AUDMOD specific-loudness model [@bramslow1993; @bramslow2004] alongside the Speech Intelligibility Index (SII) [@ansi1997].

**Study Sample:** N/A (Computational modeling of seven standardized, hypothetical audiometric profiles).

**Data Collection and Analysis:** The loudness budget is decomposed for seven canonical profiles at an average conversational speech level (65 dB SPL). Two-dimensional "feasibility maps" were generated to model achievable 2–4 kHz gain as a function of an absolute loudness cap ($L_{cap}$) and a low-frequency insertion gain floor. Finally, existing empirical formulae (NAL-NL2) and a constrained intelligibility maximizer (Open-NL) were evaluated against this feasibility frontier.

**Results:** For profiles with near-normal low-frequency hearing, unamplified speech already produces a substantial quantity of loudness ($L_0$) through residual hearing. When low-frequency insertion gain is floored at 0 dB, $L_0$ cannot be reduced, thus predetermining the remaining budget ($L_{cap} - L_0$). Feasibility maps quantify the magnitude of this trade-off, demonstrating that maximizing high-frequency gain under a typical loudness constraint necessitates active low-frequency attenuation (venting or negative insertion gain).

**Conclusions:** Loudness crowding-out is not unique to precipitous losses, but is a general structural boundary for any profile combining robust low-frequency hearing with recoverable high-frequency loss. Achieving theoretical SII maximums for these profiles physically requires intolerable low-frequency occlusion, highlighting the necessity of frequency-lowering signal processing.

## Introduction

In the fitting of precipitous or profound high-frequency hearing loss, achieving adequate high-frequency audibility without exceeding normative loudness targets is a central clinical challenge. Historically, the failure to restore high-frequency audibility has been attributed to the inherent physiological damage of the auditory periphery—specifically, hearing-loss desensitization and dead regions, which render severe high-frequency amplification effectively useless for speech recognition [@ching1998; @hogan1998]. Consequently, modern prescriptive rationales like NAL-NL2 deliberately limit high-frequency gain for profound thresholds to avoid prescribing "wasted" amplification. 

While desensitization dictates the *utility* of high-frequency gain, it is proposed that the fundamental arithmetic of broadband loudness summation acts as a parallel, independent structural constraint on the *capacity* to provide that gain. For a given audiogram and input level, unamplified speech inherently produces a baseline quantity of loudness ($L_0$) through residual hearing. If a patient's overall target loudness is constrained by a normative ceiling ($L_{cap}$), the model-predicted loudness budget available to "purchase" high-frequency audibility via prescriptive gain is defined as $L_{cap} - L_0$. Because this relationship is governed entirely by the auditory periphery and the acoustic speech spectrum, it acts as a fundamental boundary condition that profoundly constrains loudness-based rationales (e.g., NAL-NL2) and any theoretical attempt at intelligibility maximization.

While patient preference and some audiological paradigms often favor preserving or amplifying low-frequency cues in profound loss because they are the only remaining regions of robust functional hearing, the standard ANSI S3.5-1997 Speech Intelligibility Index (SII) assigns the bulk of its importance weighting to the 1-4 kHz speech bands, with relatively little weight applied below 500 Hz. Consequently, an unconstrained intelligibility-maximizing algorithm operating under a strict loudness budget will systematically attenuate low-frequency audibility to fund high-frequency gain. While it is a mathematical axiom that relaxing a constraint in an optimization algorithm yields a higher theoretical optimum, the clinical relevance lies in quantifying the sheer magnitude of this trade-off for realistic audiometric profiles. By framing this behavior as an efficiency statement relative to an absolute budget, this analysis quantifies the exact degree to which "broadband loudness crowding-out" limits high-frequency restoration, investigating whether it is uniquely tied to precipitous losses or represents a general property of near-normal low-frequency hearing.


## Methods

### The AUDMOD Specific-Loudness Model
To isolate the model-predicted loudness constraints operating on the speech spectrum, the canonical AUDMOD specific-loudness model was utilized the canonical AUDMOD specific-loudness model. This model converts acoustic excitation patterns into specific loudness (sones/ERB) and integrates them across the frequency spectrum to predict overall broadband loudness. By benchmarking the raw, unamplified long-term average speech spectrum (LTASS) through this model using the seven standard hypothetical audiometric profiles established by Johnson and Dillon [@johnson2011], the baseline loudness ($L_0$) natively generated by residual hearing was established the baseline loudness ($L_0$) natively generated by residual hearing.

### Study Sample and Audiometric Profiles
The study utilizes seven canonical audiometric profiles (A1–A7) representing standard clinical configurations (Table 3). For profiles A6 (Mixed) and A7 (Conductive), the conductive air-bone gap component is modeled in the AUDMOD specific-loudness engine as a linear attenuation block that strictly subtracts from the aided speech spectrum before it enters the cochlear simulation.

**Table 3. Canonical Audiometric Profiles (dB HL)**

| Profile | Description | $L_0$ (50) | $L_{cap}$ (50) | $L_0$ (65) | $L_{cap}$ (65) | $L_0$ (80) | $L_{cap}$ (80) |
|:---|:---|:---|:---|:---|:---|:---|:---|
| A1 | Mild | 0.40 | 3.16 | 2.65 | 9.03 | 9.22 | 22.39 |
| A2 | Reverse Slope | 0.02 | 3.16 | 1.33 | 9.03 | 6.72 | 22.39 |
| A3 | Moderate Sloping | 0.43 | 3.16 | 2.29 | 9.03 | 8.01 | 22.39 |
| A4 | Mod-Severe Precipitous | 1.85 | 3.16 | 5.77 | 9.03 | 15.25 | 22.39 |
| A5 | Profound Precipitous | 1.16 | 3.16 | 4.34 | 9.03 | 12.10 | 22.39 |
| A6 | Mixed | 0.00 | 3.16 | 0.00 | 9.03 | 0.17 | 22.39 |
| A7 | Conductive | 0.00 | 3.16 | 0.00 | 9.03 | 0.28 | 22.39 |

### The Open-NL Computational Instrument
To compute the theoretical limits of high-frequency amplification and map the boundary of achievable gain, Open-NL, a modular computational testbed, was employed Open-NL. Open-NL couples a multi-start Nelder-Mead SII optimizer to the specific-loudness engine. Rather than serving as a clinical prescription, Open-NL functions here strictly as an analytical instrument. 

For the purposes of this study, all input speech was calibrated to the standard ANSI S3.5-1997 Long-Term Average Speech Spectrum (LTASS). Because the analysis focuses entirely on average conversational speech, the Wide Dynamic Range Compression (WDRC) capabilities of Open-NL were bypassed, reducing the optimizer to a single-level linear insertion gain solver at 65 dB SPL. 

The optimizer was subjected to a global minimum insertion gain constraint across all frequency bands (the `vent_floor` parameter). While mathematically enforced as a global floor, the penalized-optimal high-frequency gain for these profiles is strictly positive; thus, the floor acts exclusively as a ceiling on low-frequency attenuation. Baseline clinical targets were generated using NAL-NL2 Version 2 software at 65 dB SPL for a symmetrical, bilateral fitting for an experienced user of unknown gender. To isolate the rationale's fundamental prescription for the audiogram from the secondary acoustic effects of venting, the targets were intentionally generated using a fully occluded (#13 tubing) coupling rather than an open fitting. While an open fitting is the clinical standard of care for these profiles, generating NAL-NL2 targets with an open coupling instructs the software to automatically cut low-frequency prescribed gain. Utilizing an occluded setting ensures the baseline targets reflect the rationale's true theoretical intent. However, it must be noted that because NAL-NL2 was parameterized for a bilateral fitting, the rationale automatically applied a binaural loudness correction that systematically lowers prescribed gain. Because the computational instruments utilized in this analysis are strictly monaural, this introduces a methodological mismatch. While this binaural correction contributes slightly to NAL-NL2's lower overall predicted loudness, the magnitude of the discrepancy is small relative to the structural boundaries of the $L_{cap} - L_0$ budget.

### C++ Instrument Validation
Because Open-NL evaluates tens of thousands of candidate gain curves during optimization, evaluating loudness via external Python or MATLAB calls introduces prohibitive computational overhead. To achieve microsecond evaluation times, the AUDMOD specific-loudness engine (AMT 1.6.0 bramslow2004) was ported entirely to C++ using `Rcpp`. 

The C++ engine was validated at three distinct levels: port fidelity, input path consistency, and absolute reference-free behavior.

First, port fidelity was established by comparing the C++ engine to the AMT `bramslow2004` (AUDMOD) implementation stage-by-stage. Across 23 test cases, the maximum relative discrepancy at any stage of computation was $5.71 \times 10^{-15}$. This comparison establishes that the C++ port reproduces AUDMOD; it does not bear on whether AUDMOD itself is accurate.

Second, the input path for spectrum construction feeding the engine was verified. The two independent routines used to compute normal-hearing speech loudness in this work return identical values at 50, 65, and 80 dB SPL (yielding 3.1577, 9.0333, and 22.3887 sones, respectively). Evaluating the 65 dB SPL speech spectrum on a 10–23990 Hz grid without renormalization yields 9.0333 sones, whereas evaluation on a 20–15000 Hz grid with renormalization yields 9.0317 sones; this difference of 0.0016 sones demonstrates that grid range and renormalization are immaterial. Furthermore, supplying a precomputed reference versus letting the wrapper build one dynamically yields identical results for profiles A1 (13.2297 sones), A4 (20.7120 sones), and A5 (16.6072 sones).

Third, the absolute behavior of the model was verified using reference-free checks, as the port and AMT would share any error. Loudness correctly evaluates to zero below threshold: for normal hearing, a 1 kHz tone remains silent up to +5 dB SPL, and for profile A5, 4 kHz remains silent up to 60 dB SPL against an 80 dB HL threshold. Recruitment is present and ordered by threshold at 4 kHz across profiles A1–A5; the apparent non-monotonicity across profiles reflects the audiometric configuration, not severity (e.g., A2 is a reverse-slope profile with a 20 dB HL threshold at 4 kHz). In normal hearing, the loudness growth for a 1 kHz tone is 1.75 to 1.91 per 10 dB above 40 phons, which characterizes the model as mildly compressive relative to the textbook expectation of a doubling per 10 dB.

A notable limitation is that the absolute sone scale is inherited from AUDMOD and has not been independently verified against loudness judgments. An attempt to check the 1 kHz / 40 dB SPL = 1 sone anchor was inconclusive: the R wrapper interpolates the input spectrum linearly in dB across a log-frequency grid, which is appropriate for the smooth, densely sampled speech spectra used throughout this work but cannot faithfully represent a pure tone. The smooth-spectrum control was stable at 9.0333 sones across every input grid spacing tested, ensuring the analyses reported here are unaffected. We do not claim the absolute scale is either correct or incorrect.


### Optimization Procedure and Grid Parameters
To construct the feasibility maps, the Open-NL optimizer was evaluated across a discretized grid spanning loudness caps from 4.0 to 9.0 sones (0.1 sone intervals) and low-frequency insertion floors from 0 to -15 dB (2.5 dB intervals). The underlying optimization routine utilized a Nelder-Mead simplex algorithm to fit a 3-parameter non-stationary gain curve (anchor gain, slope trigger, and bypass slope). 

The solutions generated are penalized-optimal rather than strictly SII-optimal. Specifically, the optimizer maximizes a nine-term penalized objective function, not raw SII. The objective consists of the SII (scaled by 100) minus eight penalty terms: an anchor penalty (`sum(abs(shifts)) * 0.1`) which acts as an L1 shrinkage toward the Open-NL heuristic prescription, a roughness penalty (`sum(diff(gain_oct)^2) * 0.001`), a loudness hinge penalty scaled at 2000 per sone over the cap, and additional out-of-bounds, SPL, order, compression ratio (CR), and air-bone gap (ABG) terms (see `R/open_nl.R` lines 268-284).

To mitigate local minima, multi-start initialization was employed across a bounded parameter grid, and the solver retains the highest value of the penalized objective, not the highest SII. Because the objective includes the anchor penalty (an L1 shrinkage toward the heuristic prescription) and the roughness penalty, additional restarts improve the objective and can return solutions with lower SII. The occasional localized inversions (e.g., slightly lower gain achieved at a -10 dB floor compared to a -5 dB floor at strict caps) follow from this property of the objective, not from a failure to converge. Local minima remain possible in this non-convex space, and the isolated region of non-convergence near 8.0 sones in the A5 map is noted separately as such.

Additionally, the number of random restarts (`open_nl_starts`) is a fixed setting (set to 20) whose value alters the prescribed gains due to the non-convex parameter space. (Note that because the random number generator seed is deterministic based on the audiogram and level, repeated runs are bit-identical and cannot be used to estimate variability.) A negative difference between floors is impossible in a genuine comparison, since the 0 dB feasible set is contained within the −10 dB set. Across the 133 paired cells at matched loudness, 46 such excursions occur; their median magnitude is 0.0009 and the largest is 0.0074. We take the maximum as the optimizer's resolution limit, so differences below roughly 0.007 are not distinguishable from solver noise.

A defect in the `open_nl()` routine caused the original minimum-gain floor contrast to report a rectified difference rather than a true effect. When called with a negative insertion floor, the function executed a dual-run branch that evaluated the optimization at both the requested floor and a strict 0 dB floor, automatically returning whichever yielded the higher raw speech intelligibility index—meaning branch selection used raw SII, whereas selection within each branch used the penalized objective (see `R/open_nl.R` lines 381–395 for 65 dB SPL and 404–418 for other levels). Consequently, the published difference between the -10 dB and 0 dB floors was not `SII(-10) - SII(0)` but `max(0, SII(-10) - SII(0))`. Across all 192 paired cells of the original audiogram family analysis, not one difference took a negative value; this is impossible in a genuine comparison because the 0 dB feasible set is contained within the -10 dB feasible set, meaning negative differences must occur wherever the true effect is small relative to optimizer precision. This bounding explains why 63 of the 192 paired cells appeared as exactly zero. These zeros were simply 0 dB solutions differenced against themselves rather than legitimate null results. Their frequency rose with the audible edge frequency, from 31% of cells at 1000 Hz to 61% at 3000 Hz, consistent with the 0 dB branch winning most often where relaxing the floor helps least. Because this defect was isolated to branch selection and did not compromise the underlying loudness engine or the optimizer itself, the analysis code for this paper disables the dual-run branch so that each floor is optimized exactly once at the floor requested (the original package behavior is documented in a separate issue). The affected results have been recomputed under this corrected methodology and are reported below as side-by-side solutions with their achieved loudness.

## Results

### Loudness Budget Decomposition
To establish the model-predicted loudness constraints operating on high-frequency amplification, the unamplified loudness ($L_0$) produced by speech across three conversational input levels (50, 65, and 80 dB SPL) was first computed. This baseline was then compared against a normative broadband loudness ceiling ($L_{cap}$) for each level. 

To avoid arbitrary definitions of tolerance, the normative target ceilings ($L_{cap}$) are strictly defined as the normal-hearing loudness of unaided speech at the evaluation level. When the 50, 65, and 80 dB SPL long-term average speech spectra are processed through the specific-loudness engine for a 0 dB HL profile, the model predicts overall loudnesses of 3.16, 9.03, and 22.39 sones, respectively. These ceilings are identical for all listeners and are not listener-specific. The difference ($L_{cap} - L_0$) therefore represents the remaining model-predicted loudness budget available to "purchase" high-frequency audibility via prescriptive gain before exceeding normal-hearing loudness limits.

An empirical anchor for this ceiling would be preferable to a normative one, so we tested whether an established rationale provides one. It does not: NAL-NL2-prescribed aided loudness for 65 dB SPL speech, expressed as a fraction of the normative ceiling, scatters by nearly a factor of two with no consistent value (0.46 for A1, 0.39 for A2, 0.40 for A3, 0.73 for A4, and 0.61 for A5). Because NAL-NL2 optimizes loudness against its own criteria rather than targeting a fixed proportion of normal-hearing loudness, it cannot be used to calibrate this parameter.

$L_{cap}$ is therefore a modelling assumption, not a measured quantity. Because true loudness discomfort or target loudness can vary significantly across individual patients and fitting rationales, analyzing a single fixed normative cap for 65 dB SPL speech (e.g., 9.03 sones) fails to capture the full optimization boundary. This is why the feasibility maps treat the loudness cap as a continuous axis rather than a fixed value: the sweep across caps is the sensitivity analysis for this assumption, and conclusions that hold across the range do not depend on the particular value chosen.

Table 1 presents this decomposition for the seven canonical audiometric profiles. For mild (A1) or moderate sloping (A3) profiles, unamplified speech consumes a minority of the normative loudness budget across all levels. This leaves ample capacity for prescriptive algorithms to apply positive insertion gain across the frequency spectrum. 

**Table 1. Loudness Budget Decomposition (Sones) across Audiometric Profiles at 50, 65, and 80 dB SPL**

| Profile | Description | $L_0$ (50) | $L_{cap}$ (50) | $L_0$ (65) | $L_{cap}$ (65) | $L_0$ (80) | $L_{cap}$ (80) |
|:---|:---|:---|:---|:---|:---|:---|:---|
| A1 | Mild | 0.40 | 3.16 | 2.65 | 9.03 | 9.22 | 22.39 |
| A2 | Reverse Slope | 0.02 | 3.16 | 1.33 | 9.03 | 6.72 | 22.39 |
| A3 | Moderate Sloping | 0.43 | 3.16 | 2.29 | 9.03 | 8.01 | 22.39 |
| A4 | Mod-Severe Precipitous | 1.85 | 3.16 | 5.77 | 9.03 | 15.25 | 22.39 |
| A5 | Profound Precipitous | 1.16 | 3.16 | 4.34 | 9.03 | 12.10 | 22.39 |
| A6 | Mixed | 0.00 | 3.16 | 0.00 | 9.03 | 0.17 | 22.39 |
| A7 | Conductive | 0.00 | 3.16 | 0.00 | 9.03 | 0.28 | 22.39 |

However, a severe structural bottleneck emerges in precipitous profiles (A4 and A5) across the entire dynamic range. For profile A4, near-normal low-frequency thresholds allow unamplified speech at 50 dB SPL to inherently generate 1.85 sones of loudness. Against the normative 3.16 sone ceiling, this leaves 1.31 sones of budget for amplification. At 80 dB SPL, the unamplified speech produces 15.25 sones against a 22.39 cap. Crucially, if a prescriptive formula enforces a rigid low-frequency insertion gain floor of 0 dB (preventing attenuation), these $L_0$ values cannot be reduced. The budget is thus exhausted before the algorithm can allocate the immense high-frequency gain required to cross the profound high-frequency thresholds, causing high-frequency audibility to be systematically crowded out by residual low-frequency hearing at all input levels.

### Feasibility Maps

Because the cap is a modelling assumption rather than a measured quantity, the loudness cap ($L_{cap}$) is treated not as a fixed value but as a continuous axis. Figure 1 and Figure 2 present "Feasibility Maps" for the precipitous profiles A4 and A5, respectively. Rather than plotting absolute maximum achievable gain, these contour plots map the 2-4 kHz high-frequency gain of the *penalized-optimal solution* as a two-dimensional surface over the absolute loudness cap (X-axis) and the low-frequency insertion gain floor (Y-axis, extending down to -15 dB). To visualize the behaviorally realistic intelligibility impact, corresponding maps plotting the maximum achieved desensitized SII (applying the complete Johnson and Dillon (2011) penalty) across the same grid are also provided.

![Figure 1A. Feasibility map for the moderate-severe precipitous profile A4, showing achievable 2-4 kHz insertion gain as a function of the loudness cap and low-frequency insertion floor. The position of NAL-NL2 is marked for comparison.](figures/feasibility_a4.png)
![Figure 1B. Corresponding SII map for profile A4, illustrating the maximum achievable desensitized SII across the constraint grid.](figures/feasibility_sii_a4.png)

![Figure 2A. Feasibility map for the profound precipitous profile A5, illustrating the severe structural crowding-out effect.](figures/feasibility_a5.png)
![Figure 2B. Corresponding SII map for profile A5.](figures/feasibility_sii_a5.png)

For these steeply sloping profiles, the contour gradient visualizes the structural interaction between the available budget and the low-frequency floor. As seen in the A5 map (Figure 2A), when the loudness cap exceeds approximately 6.0 sones, the contours become primarily vertical, indicating that the overall loudness budget is sufficiently large that the low-frequency floor is no longer a binding constraint; the optimizer simply reaches the upper gain bounds permitted by its internal parameterization (a saturation ceiling of roughly 45 dB of high-frequency gain for A5). 

However, at the stricter normative caps targeted by clinical rationales, the floor effect becomes highly binding. To quantify this magnitude, specific coordinates can be extracted from the A4 feasibility map. If a patient's target loudness is constrained specifically to NAL-NL2's baseline of 6.56 sones, restricting the insertion floor to 0 dB limits the maximum theoretical penalized-optimal 2–4 kHz gain to 21.3 dB. Relaxing the floor to -10 dB frees up enough model-predicted loudness capacity to push the penalized-optimal high-frequency gain to 29.9 dB—an increase of over 8 dB in the critical speech bands.

By relaxing the floor toward -10 or -15 dB (moving downward on the Y-axis), the optimizer is permitted to actively suppress the normal-hearing low frequencies. This suppression frees up loudness capacity, allowing the solver to prescribe substantially more high-frequency gain before hitting the target loudness cap.

When standard NAL-NL2 targets are projected onto these maps, the resulting dynamics align perfectly with physiological expectations. For profile A4 (Figure 1A), NAL-NL2 targets a loudness of 6.09 sones with an effective floor of exactly 0.0 dB at 250 and 500 Hz, and prescribes an average of 17.2 dB of 2-4 kHz insertion gain. This point sits inside the absolute efficiency frontier (which maxes out at 21.3 dB for that exact 6.09, 0 coordinate). Similarly, for the profound A5 profile (Figure 2A), NAL-NL2 prescribes 23.9 dB of high-frequency gain at 5.53 sones, well below the theoretical boundary. Because NAL-NL2 incorporates physiological desensitization and dead-region penalties, it appropriately limits high-frequency gain long before the absolute loudness budget is exhausted. Consequently, any clinical algorithm attempting to indiscriminately maximize raw audibility (pushing beyond NAL-NL2 to hit the boundary) will rapidly collide with the loudness constraint, at which point further high-frequency restoration mathematically requires negative low-frequency insertion gain.

### The Audiogram Family Sweep

Sixteen synthetic audiograms crossing four audible edge frequencies (1000, 1500, 2000, 3000 Hz) with four high-frequency slopes (20, 30, 40, 50 dB/octave) were evaluated at four loudness budgets (0.5, 1, 2, and 3 sones above each listener's own unaided loudness), three desensitization scales (0, 0.5, 1), and two minimum-gain floors (0 and -10 dB). Each floor was optimized once at the floor requested with 20 random restarts, and solutions at the two floors are reported side by side with their achieved loudness rather than as a difference.

In 133 of the 192 paired cells, the two solutions differ in achieved loudness by no more than 0.001 sones, so the comparison is like-for-like at matched loudness; the cells that fail this test are concentrated at the loosest budget, where the loudness cap stops binding and the optimizer no longer spends the capacity available to it. Because the 0 dB feasible set is contained within the -10 dB set, a negative difference between floors is impossible in a genuine comparison; any negative value therefore measures the optimizer's precision rather than a real difference. Among the 133 matched-loudness cells, 46 such excursions occur, with a median magnitude of 0.0009 and a largest of 0.0074. This largest excursion is taken as the optimizer's resolution limit, so differences below roughly 0.007 are not distinguishable from solver noise.

At the tightest budget, the mean SII change from relaxing the floor is 0.079, 0.054, and 0.038 at a 1000 Hz audible edge for desensitization scales 0, 0.5, and 1 respectively; 0.023, 0.016, and 0.009 at 1500 Hz; 0.010, 0.008, and 0.005 at 2000 Hz; and approximately zero at 3000 Hz. The effect declines monotonically with desensitization scale and with loudness budget. It is unambiguous at 1000 and 1500 Hz, comparable to the resolution limit at 2000 Hz, and indistinguishable from zero at 3000 Hz. At the tightest budget and a 1000 Hz audible edge, averaged across desensitization scales, prescribed gain falls by 6.8 dB at 500 Hz, 3.3 dB at 1000 Hz, and 7.9 dB at 8 kHz, and rises by 10.0 dB at 2000 Hz and 6.4 dB at 4000 Hz. Because the paired solutions are at matched loudness, these changes trade off against one another: capacity is drawn from the near-normal low frequencies and from 8 kHz, and spent in the 2-4 kHz region.

### Formula Evaluation: Iso-Loudness Control
To isolate the exact SII cost of preventing low-frequency attenuation, an iso-loudness control experiment was conducted. The Open-NL intelligibility maximizer was constrained to match the *exact* mathematical loudness output generated by NAL-NL2 for each profile at 65 dB SPL. It was then optimized twice: once with a strict 0 dB low-frequency insertion gain floor, and once with a -10 dB floor. 

During optimization, Open-NL maximizes a modified SII incorporating a smoothed implementation of the Johnson and Dillon (2011) [@johnson2011] desensitization penalty, aligning its internal objective function closely with the physiological assumptions of NAL-NL2. To ensure rigorous evaluation, both formulas were scored in Table 2 using the complete Johnson and Dillon (2011) desensitized SII metric. By perfectly aligning the reported index with the metric the optimizer actually maximizes, any measured changes can be conclusively attributed to the mathematical boundaries rather than objective function mismatch. The primary goal is not to claim algorithmic superiority over the clinical rationale, but to isolate the exact efficiency cost of the 0 dB insertion floor within a rigidly controlled mathematical space.

Table 2 details the difference in achieved desensitized SII when both the formula and the optimizer are constrained to the same total sones. By separating the *optimizer effect* (the difference between Open-NL at 0 dB and NAL-NL2) from the *floor effect* (the difference between Open-NL at -10 dB and 0 dB), the precise mechanism of loudness crowding-out becomes clear. 

**Table 2. Iso-Loudness Control: Desensitized SII (Constrained to NAL-NL2 Loudness at 65 dB SPL)**

| Profile | NAL-NL2 Loudness | NAL-NL2 SII | Open-NL (0 dB) | Open-NL (-10 dB) | Optimizer Effect | Floor Effect |
|:---|:---|:---|:---|:---|:---|:---|
| A1 (Mild) | 4.14 sones | 0.734 | 0.753 | 0.786 | +0.019 | +0.033 |
| A2 (Reverse Slope) | 3.51 sones | 0.769 | 0.788 | 0.799 | +0.019 | +0.011 |
| A3 (Moderate Sloping) | 3.63 sones | 0.608 | 0.605 | 0.678 | -0.003 | +0.073 |
| A4 (Mod-Severe Precipitous) | 6.56 sones | 0.670 | 0.699 | 0.719 | +0.029 | +0.020 |
| A5 (Profound Precipitous) | 5.50 sones | 0.539 | 0.586 | 0.595 | +0.047 | +0.009 |
| A6 (Mixed) | 2.10 sones | 0.717 | 0.719 | 0.719 | +0.003 |  0.000 |
| A7 (Conductive) | 3.10 sones | 0.971 | 0.976 | 0.976 | +0.005 |  0.000 |

Scoring with the desensitized SII reveals a strikingly different decomposition than raw ANSI SII would suggest, and one that is far more clinically realistic. The floor effect is highly variable, with the moderate sloping profile A3 showing the largest benefit (+0.073) from relaxing the low-frequency floor, followed by the mild profile A1 (+0.033). For the precipitous profiles, the floor effect provides a modest benefit for A4 (+0.020) but remains small but measurable for A5 (+0.009). The desensitized SII improvement over NAL-NL2 for these profound losses instead comes substantially from the optimizer effect: +0.029 for A4 and +0.047 for A5. Because the desensitization penalty heavily discounts audibility in the profoundly impaired high frequencies, freeing up additional loudness capacity via low-frequency attenuation yields limited marginal desensitized SII benefit for the steepest high-frequency losses — much of the extra gain is prescribed into frequency regions where the Johnson and Dillon (2011) penalty renders it less valuable.

This result has two important implications. First, it confirms that NAL-NL2's conservative high-frequency gain limits are well-aligned with desensitized intelligibility: the gap between NAL-NL2 and the 0 dB optimizer is modest, while relaxing the floor adds a further benefit that varies substantially across profiles and is largest where high-frequency loss is least severe. Second, the structural loudness crowding-out documented in the feasibility maps remains a genuine acoustic boundary, but its *clinical* impact as measured by desensitized SII is substantially attenuated by the very physiological limits that motivated the desensitization correction. The crowding-out constraint is most consequential for profiles where high-frequency loss is moderate enough that the desensitization penalty is small — precisely the profiles (like A3) where the floor effect is largest. Supporting this, the benefit of relaxing the floor shrinks as the desensitization penalty strengthens: for A3 the floor effect is +0.094 with no desensitization, +0.073 smoothed, and +0.045 complete, while for A5 it is +0.006, +0.009, and -0.002 across the three treatments.

For the mixed and conductive profiles (A6, A7) the floor effect is exactly zero and no frequency band receives negative gain, so the floor never engages. For A2, the reverse-slope profile, the band receiving negative gain is 4000 Hz rather than the low frequencies—the only such case—which naturally follows from the reverse-slope configuration. As a caveat, for A1 the two solutions differ in achieved loudness by 0.016 sones, so that profile alone is not exactly iso-loudness; every other profile matches to within 0.002 sones.

## Discussion

The computational mapping of the $L_{cap} - L_0$ budget clearly visualizes that the achievable high-frequency gain for precipitous losses is bounded by acoustic arithmetic as an independent constraint. For a profile like A4 at 65 dB SPL, unamplified speech inherently generates 5.77 sones of loudness. If evaluated against a strict 9.03 sone normal-hearing ceiling, this unamplified energy consumes roughly 64% of the total capacity before a single decibel of prescriptive gain is applied, though this exact proportion is highly dependent on the chosen $L_{cap}$. While empirical rationales like NAL-NL2 correctly limit high-frequency gain in these profiles due to physiological desensitization (leaving a small fraction of the loudness budget unused), any clinical attempt to aggressively restore high-frequency audibility beyond these conservative limits (e.g., to maximize raw SII) will immediately collide with this budget constraint. When clinical software enforces a minimum 0 dB insertion gain floor, the remaining budget is quickly exhausted.

This constraint forces a harsh physical reality in clinical practice. The penalized-optimal solutions in the feasibility maps rely on negative low-frequency insertion gain to free up loudness capacity. However, digital gain reduction cannot bring the ear canal level below the direct sound path in an open fitting. To achieve true negative low-frequency insertion gain, a clinician must use a highly occluding earmold to physically attenuate the incoming low frequencies. Because precipitous profiles possess near-normal low-frequency hearing, occluding the ear canal will induce a severe, often intolerable occlusion effect (e.g., autophony and boomy own-voice). 

Conversely, if the clinician opts for an open or vented fitting to avoid occlusion (the standard standard of care for precipitous losses), the direct sound path locks the low-frequency insertion gain floor at $\ge 0$ dB. As demonstrated by the feasibility maps, this instantly traps the fitting at the 0 dB contour, drastically reducing the achievable high-frequency gain before the loudness cap is breached. This theoretical limitation is compounded by practical electroacoustic constraints: open fittings suffer from severe acoustic feedback, which independently limits the maximum stable high-frequency gain a device can deliver.

Crucially, this analysis does not suggest that clinicians should actively pursue these theoretical SII maximums by occluding patients and aggressively attenuating low frequencies. Due to physiological desensitization and cochlear dead regions, the standard ANSI SII is known to overpredict actual behavioral speech recognition in profound high-frequency losses. Applying massive high-frequency gain often yields diminishing or even negative behavioral returns for these patients. Rather, this index-level analysis serves to map the absolute boundaries of the acoustic parameter space. It demonstrates that even if a clinician *wished* to pursue higher high-frequency gain—perhaps for a patient with exceptionally robust high-frequency neural survival—they are structurally blocked by the loudness budget arithmetic of the open fitting.

Ultimately, maximizing the theoretical Speech Intelligibility Index through raw high-frequency gain in precipitous losses is fundamentally a direct trade-off against residual low-frequency hearing, and achieving it physically requires intolerable occlusion. This structural bottleneck perfectly illustrates why alternative signal processing strategies, such as nonlinear frequency compression or transposition, are so critical. By shifting high-frequency speech cues into lower-frequency regions, these algorithms bypass the need for massive high-frequency gain, circumventing both the broadband loudness budget and the limits of high-frequency physiological desensitization entirely.

### Limitations
Several methodological constraints should be noted when interpreting these computational results. First, the specific-loudness engine utilizes a monaural model; it does not explicitly capture the complex dynamics of bilateral loudness summation in impaired listeners. Second, the framework applies stationary loudness integration to a static long-term average speech spectrum (LTASS). Real-world speech is highly time-varying, and dynamic compression systems (WDRC) acting on fluctuating speech may yield different instantaneous loudness profiles. Furthermore, the analysis is fundamentally a theoretical, index-level optimization; it lacks behavioral validation and does not directly measure patient speech recognition outcomes. Finally, the simulations were deliberately constrained to a single standard speech spectrum and the seven hypothetical canonical audiograms defined by Johnson and Dillon (2011). While this standardizes the mathematical analysis, a broader corpus of real-world audiometric profiles and variable speech inputs would be required to generalize these constraints across the diverse clinical population.

Additionally, the loudness budget framework is limited in its application to the mixed (A6, 30 dB conductive component) and conductive (A7, 50 dB conductive component) profiles. Because unaided speech is inaudible at conversational levels—only becoming audible at 80 dB SPL with 0.17 and 0.28 sones—"budget above unaided" degenerates to an absolute ceiling for these profiles. Evaluated against the 9.03-sone ceiling at 65 dB SPL, both NAL-NL2-aided (2.10 and 3.10 sones; fractions of 0.23 and 0.34) and Open-NL-aided prescriptions (3.46 and 3.84 sones; fractions of 0.38 and 0.42) use a smaller fraction of the budget than for any sensorineural profile (A1–A5 range 0.39 to 0.73). This is consistent with attenuation without recruitment, and the binding constraint for mixed and conductive losses is therefore the air-bone-gap anchoring rather than the loudness cap.

## Data Availability
The code used to execute the computational simulations, reproduce the dataset, and generate all figures for this study is fully open-source and available on GitHub (https://github.com/r-gregmisc/SII).

## References

