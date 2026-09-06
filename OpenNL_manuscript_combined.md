---
title: "Open-NL: A Transparent Computational Testbed for Wide Dynamic Range Compression"
author:
- "Mark Shaver$^1,a)$"
- \parbox{\textwidth}{\centering $^1$ Wichita State University, Department of Communication Sciences and Disorders, 1845 Fairmount St, Wichita, KS 67260, USA}
- "$^{a)}$Email: mark.shaver@wichita.edu"
output: 
  pdf_document:
    number_sections: false
    keep_tex: true
fontsize: 12pt
geometry: margin=1in
indent: true
linestretch: 2
header-includes:
  - \usepackage{indentfirst}
  - \usepackage{lineno}
---

\linenumbers

## Abstract
**Open-NL** is an open-source computational testbed designed for the transparent modeling and evaluation of Wide Dynamic Range Compression (WDRC) prescriptive rules. Modern prescriptions like NAL-NL2 rely on extensive empirical regularizations to ensure clinical safety. These safeguards counteract the well-documented failures of pure intelligibility maximization. However, clinical software remains closed-source. This prevents researchers from isolating how specific heuristic safeguards interact. 

Open-NL addresses this limitation. It couples a multi-start Nelder-Mead Speech Intelligibility Index (SII) optimizer with the Moore & Glasberg (2004) specific-loudness model. We benchmark this testbed across a $4^4 = 256$-permutation heuristic sweep alongside a 5-iteration multi-start stability analysis. This approach establishes a fundamental distinction between numerical convergence and heuristic sensitivity. The multi-start solver exhibits high numerical stability ($	ext{SD} < 0.025$ SII) for any fixed parameter set. In contrast, prescribed targets display extreme heuristic sensitivity in severe-sloping configurations. Minor rule modifications can swing modeled monaural loudness between 0.9 and 5.3 sones. 

Standard monaural models systematically underestimate real-world binaural broadband summation. Therefore, this modeled loudness frontier is strictly illustrative rather than clinically definitive. When stripped of clinical heuristics, the optimizer dramatically inflates high-frequency gain in profound profiles. This behavior demonstrates the theoretical limits of pure mathematical optimization against real-world clinical bounds. Open-NL exposes these critical trade-offs within a fully inspectable framework. Ultimately, it provides the computational substrate for future calibration workflows, paving the way to replace static heuristic boundaries with individualized, distortion-aware objective functions.

## I. INTRODUCTION

Manufacturer-agnostic prescriptions remain central to evidence-based hearing aid practice. While earlier investigations suggested that generic targets might outperform proprietary first-fit algorithms on patient preference and specific metrics (Valente et al., 2018), contemporary evidence indicates that aided speech recognition in noise often shows no significant difference across formulas. However, while formula choice has relatively modest intelligibility consequences in background noise, it drives substantial variations in overall loudness, making modeled loudness (quantified in sones per the Moore & Glasberg 2004 impaired loudness model) the primary dependent variable in prescriptive evaluation.

While the derivations of major algorithms like NAL-NL2 and DSL m[i/o] are published in detail, their software implementations remain closed-source. Audiological science has long recognized that unconstrained intelligibility maximization fails clinically without extensive empirical regularization. For example, the evolution from NAL-NL1 to NAL-NL2 required critical empirical corrections. These included global gain reductions and reduced compression ratios for severe losses. These safeguards were introduced specifically to counteract the aggressive over-amplification provoked by pure mathematical optimization (Keidser, Dillon, Carter, & O'Brien, 2012a). 

Because clinical fitting software packages are compiled black boxes, researchers cannot isolate individual heuristic rules. It remains impossible to observe how specific safeguards interact within the optimization cascade. Existing open-source tools serve distinct, separate functional niches. The openMHA platform (Herzke et al., 2017) operates as a real-time signal processing master hearing aid rather than a target generator. The Cambridge CAM2/CAMEQ2-HF formulae (Moore et al., 2010) provide rigidly defined equation-based targets rather than a modular optimization sandbox. Finally, the Auditory Modeling Toolbox (AMT; Majdak et al., 2022) offers loudness modeling without native prescriptive inversion. Consequently, investigators cannot isolate a specific prescriptive heuristic within an optimization loop without reverse-engineering an entire proprietary engine. 

Open-NL fills this gap. It provides a modifiable R substrate explicitly designed for the modular ablation of prescriptive heuristics. By coupling a Nelder-Mead desensitized SII optimizer to an integrated C++ specific-loudness engine, researchers can systematically disable, isolate, or invert individual heuristics. For instance, investigators can evaluate the upward spread of masking when disabling the 30 dB conductive safety cap. This modular architecture aligns directly with evolving audiological frameworks, such as the multi-profile philosophy introduced in NAL-NL3 (Kitterick et al., 2026).

Crucially, to benchmark this testbed without introducing confounding variables, the optimization layer is embedded within a strictly reproduced evaluation paradigm. The seven reference audiometric profiles, the Moore & Glasberg (2004) specific-loudness model, and the ANSI S3.5 SII metric utilized herein are a direct replication of the methodological framework established by Johnson and Dillon (2011). (Throughout this manuscript, "ANSI SII" refers to raw physical audibility, whereas "smoothed desensitized SII" or "complete desensitized SII" refers to audibility incorporating severe-loss desensitization and level distortion penalties). Because this physiological evaluation space is already established in the literature, the primary contribution of this manuscript is the transparent computational testbed itself. By exposing the behavior of numerical solvers within this standardized sandbox, we clarify a crucial distinction: while numerical solvers converge stably on any fixed objective space, theoretical WDRC target generation exhibits acute parameter sensitivity to uncalibrated heuristic boundaries, providing the computational infrastructure necessary to quantify and calibrate these interactions.

### Clinical Safety and Usage Disclaimer

It is imperative to state unambiguously that Open-NL is strictly a computational research testbed and **must not be used for fitting hearing aids on human listeners in its current form**. Because the framework deliberately permits aggressive, over-prescriptive targets for boundary testing—such as utilizing an aggressive 60 dB HL severe-loss booster onset that permits 14–15 sones of theoretical loudness for profound losses—it carries a significant risk of severe over-amplification. As established by Ching, Dillon, Katsch, and Byrne (2001), aggressive high-level targets in steeply sloping or profound losses are precisely where over-amplification risks are greatest, as the effectiveness of high-frequency audibility severely degrades as hearing loss worsens (desensitization). The hypotheses and targets generated by Open-NL represent extreme mathematical boundaries intended to trigger experimental loudness rejection in controlled research settings, not clinical solutions. Any future behavioral translation of this framework requires independent institutional review, with mandatory real-ear verification and strict, individualized loudness-tolerance limits implemented as absolute prerequisites.

## II. ALGORITHM ARCHITECTURE

### A. Prescriptive Rationale and Objective Function

The choice of objective function is the primary design decision in any prescriptive formula. It governs the fundamental trade-off between intelligibility and comfort. Historically, established rationales occupy distinct positions on this spectrum. NAL-NL2 maximizes speech intelligibility while constraining overall broadband loudness to be less than or equal to that of a normal-hearing listener (Keidser, Dillon, Carter, & O'Brien, 2012a). Conversely, DSL m[i/o] normalizes loudness across frequency to restore normal dynamic range perception (Scollie et al., 2005). Finally, CAMEQ/CAM2 aim to equalize loudness across frequency bands (Moore, Glasberg, & Stone, 2010).

Open-NL positions its prescriptive rationale as a *constrained intelligibility-maximizer*. Its primary mathematical objective is the unconstrained maximization of desensitized SII. Rather than globally restricting this maximization to a static "normal-or-less" loudness boundary, Open-NL permits dynamic loudness growth. This growth continues until it strikes a U-shaped physiological ceiling (controlled via `cap_knots`; Section S.I.12). For severe losses, this penalty explicitly permits slightly higher-than-normal loudness in the mid-frequencies, where intelligibility yield is highest. However, it aggressively decelerates loudness growth at spectral extremes.

Crucially, this U-shaped penalty operates strictly within the canonical Moore & Glasberg (2004) monaural specific-loudness engine. It dynamically restricts modeled monaural sones. However, it does not—and mathematically cannot—account for the idiosyncratic binaural broadband loudness summation observed in hearing-impaired listeners. In normal-hearing auditory physiology, bilateral acoustic presentation produces a modest binaural loudness summation. This is typically modeled by a 2–6 dB level-dependent gain reduction. 

However, robust psychoacoustic evidence demonstrates a stark contrast in impaired ears. Binaural broadband summation in hearing-impaired populations averages ~13 dB higher than in normal-hearing listeners. This represents an unmodeled factor of $\approx 2.4\times$ in linear sones (Denk et al., 2025; Moore et al., 2014; Oetting et al., 2016, 2017). Approximately 30–40% of hearing-impaired listeners exhibit excess summation far exceeding the normal range. Individual summation values span a massive -10 to +40 dB envelope. 

Standard monaural and narrowband loudness models cannot predict this broadband suprathreshold phenomenon from the pure-tone audiogram alone. Therefore, an algorithm optimized strictly beneath a monaural ceiling becomes structurally anti-conservative when translated to bilateral fittings. Consequently, Open-NL's U-shaped loudness constraint must be interpreted strictly as an illustrative computational boundary for single-ear simulation, rather than an empirical safety guarantee for bilateral clinical use.

### B. Methods and Development

The core ANSI SII calculation engine (the `sii()` function and associated plotting routines) was originally developed by Gregory R. Warnes for earlier package versions. Maintainership transferred to the current author with version 1.1.0, at which point all subsequent Open-NL prescriptive logic, clinical heuristics, and WDRC mathematical implementations—including `open_nl()`, `calculate_loudness()`, and `launch_app()`—were developed by the author as original contributions. In accordance with AIP Publishing guidelines, AI tool usage is explicitly disclosed: Google Gemini (DeepMind, Google LLC) was utilized as an interactive programming and copyediting assistant for refactoring C++ and R algorithms, generating data visualizations, and condensing manuscript prose into JASA standards. The author rigorously reviewed and verified all outputs, taking full responsibility for algorithm design, data integrity, and manuscript content. Specifically, all AI-refactored computational logic was systematically verified by executing exact numerical regression tests against pre-refactor outputs across the seven canonical audiometric profiles, ensuring absolute mathematical parity during translation.

### C. Algorithmic Pipeline and Execution Cascade

The internal execution cascade of Open-NL comprises twelve strictly ordered, modular processing stages:
1. **Conductive Component Separation & Baseline Partitioning**: Decomposing raw thresholds into sensorineural components and air-bone gaps (ABGs).
2. **Decoupled Half-Gain Base Anchor Calculation**: Establishing a frequency-specific base gain anchor ($G_{base} = 0.46 \cdot \text{HTL}_{sn} + C_{interp}$) decoupled from broadband PTA.
3. **Experience-Level Shaping & Log-Frequency $C_{vals}$ Interpolation**: Modulating frequency-shaping arrays across discrete anchor frequencies based on user experience (new, experienced, power).
4. **Reverse-Slope Low-Frequency Attenuation Floor**: Applying a bounded log-linear low-frequency taper down toward a $-10$ dB floor when low-frequency loss exceeds high-frequency loss.
5. **Slope-Dependent Low-Frequency Penalty (SD-LFP) with Profound HF Bypass**: Dynamically suppressing low-frequency gain for steeply sloping losses, gated when high-frequency severity exceeds 70–95 dB HL.
6. **Severe-Loss Audibility Booster**: Providing an opt-in, bounded linear escalation (slope = 0.15) for severe thresholds.
7. **Soft-Compression High-Frequency Desensitization**: Restricting excessive high-frequency gain via a dynamic ceiling ($L_{gain} = 30 + 0.4 \cdot \max(0, \text{HTL}_{sn} - 60)$) and 2:1 soft compression.
8. **Dynamic Range Mapping (LDL Squeeze)**: Attenuating gain by 0.2 dB/dB of reduced dynamic range and shifting baseline compression ratios.
9. **Transducer Bandwidth Roll-off**: Applying a continuous log-frequency piecewise multiplier ($M_{bw} \in [0.5, 1.0]$) to suppress unstable edge frequencies ($\le 250$ Hz and $\ge 6000$ Hz).
10. **Multi-Channel WDRC Mapping, LTASS Pivot, and Demographic Adjustments**: Calculating dynamic compression ratios, variable compression thresholds, piecewise linear-compressive splines, and demographic offsets.
11. **Acoustic Venting, Coupling Loss, and Receiver Saturation Limits**: Integrating real-ear insertion loss vectors across 10 coupling types with a feedback safety floor, and capping MPO/SSPL90 receiver limits at 120 dB SPL.
12. **Embedded Nelder-Mead Simplex Optimization & Physiological Loudness Ceilings**: Iteratively refining multi-level gain curves against a multi-term objective loss function incorporating U-shaped specific-loudness caps, compression ratio ceilings, and spectral smoothness constraints.

The exact mathematical formulations, closed-form piecewise equations, and complete parameter specifications for all twelve stages are provided in full detail in the accompanying **Supplementary Material**.

### D. Consolidated Constants and Evidentiary Asymmetry

Because Open-NL functions as a modifiable computational testbed, several structural parameters remain mathematically uncalibrated: the 0.46 gain anchor, 0.15 severe-loss booster slope, 70 dB HL booster onset (or 60 dB HL in aggressive mode), 15 dB slope trigger, 20 dB taper width, -10 dB reverse-slope floor, 70 dB HL bypass, 30 dB/0.4 $L_{gain}$ constraint, 0.2 dB/dB dynamic range squeeze, 75% air-bone-gap restoration fraction, and 1.5:1 Comfort-in-Noise (CIN) compression clamp (Table S1).

Crucially, an inspection of these heuristics reveals a profound **asymmetry in evidentiary support**. Several prominent constants—most notably the 75% air-bone-gap restoration rule and the 1.5:1 Comfort-in-Noise clamp—are pragmatic engineering choices without direct empirical derivation. The 75% ABG fraction, while standard in clinical prescriptive software (Johnson, 2013a) to avoid receiver saturation and MPO clipping, has never been empirically established against patient preference or speech recognition. Similarly, the 1.5:1 CIN clamp is an asserted heuristic inspired by NAL-NL3 (Kitterick et al., 2026) to mitigate listening fatigue, but lacks independent perceptual validation. In sharp contrast, the 3.0:1 Compression Ratio (CR) upper ceiling enforced across the WDRC stages and optimizer loss function represents the **best-supported constant in the framework**. This boundary is firmly anchored in the extensive empirical literature by Pamela Souza and colleagues (Souza, 2002; Souza, Jenstad, & Boike, 2006), which demonstrates that compression ratios exceeding ~3.0:1 cause severe temporal envelope flattening, loss of acoustic contrast, and speech-in-noise deficits. Documenting this asymmetry prevents conflating validated psychoacoustic limits with arbitrary engineering heuristics.

### E. Framework for Principled Calibration

For a computational testbed to provide lasting inferential value, demonstrating parameter instability must be paired with a rigorous calibration pathway. Future research can utilize Open-NL within a global stochastic optimization framework (e.g., genetic algorithms or particle swarm optimization) to systematically calibrate these heuristic gates. In this architecture, an outer optimization loop searches the multidimensional space of heuristic constants (e.g., $G_{base} \in [0.3, 0.6]$, booster onset $\in [50, 80]$ dB HL, low-frequency slope $\in [0, 0.5]$). For each candidate vector, the inner Open-NL engine generates discrete WDRC targets across a representative clinical corpus (e.g., NHANES). These targets are evaluated through a time-domain acoustic simulation pipeline (e.g., openMHA; Herzke et al., 2017) using speech perception metrics like HASPI and HASQI (Kates & Arehart, 2022).

Crucially, the outer-loop objective function must incorporate an asymmetric, veto-based cost function: any parameter configuration violating individualized broadband loudness tolerance (trueLOUDNESS; Oetting et al., 2017) in simulated outlier listeners must incur an overwhelming penalty. As detailed in Section II.A, because excess binaural broadband summation cannot be predicted from pure-tone thresholds, static 2–6 dB bilateral corrections are structurally inadequate. Subordinating population-level intelligibility maximization to individualized physiological safety limits transforms prescriptive derivation into a reproducible, distortion-aware computational science.

**TABLE I. Summary of Algorithmic Constants, Evidentiary Support, and Proposed Calibration Pathways.**

- **Base Gain Anchor** (Value: 0.46)
  - *Description*: Half-gain multiplier ($G_{base}$)
  - *Justification*: Balances Lybarger half-gain rule with historical gain preference data (uncalibrated midpoint).
  - *Proposed Calibration*: Large-scale preferred listening level datasets (e.g., NHANES-derived preference corpus)

- **New-User Offset** (Value: up to -6 dB based on PTA)
  - *Description*: Dynamic reduction applied to output gain
  - *Justification*: Approximates empirical preference for less amplification in naive users (asserted heuristic).
  - *Proposed Calibration*: Longitudinal acclimatization studies (Categorical Loudness Scaling)

- **Severe-Loss Booster Slope** (Value: 0.15)
  - *Description*: Applied linearly to thresholds 70–80 dB HL (default)
  - *Justification*: Gently assists profound losses without triggering explosive recruitment (asserted heuristic).
  - *Proposed Calibration*: Individualized UCL/trueLOUDNESS broadband summation limits

- **High-Frequency Gain Cap Base** (Value: 30 dB)
  - *Description*: Base limit for $L_{gain}$ soft-compression
  - *Justification*: Manages upward spread of masking and distortion in severe impairments (asserted heuristic).
  - *Proposed Calibration*: HASPI/HASQI speech-in-noise behavioral thresholds (e.g., WIN/HINT)

- **High-Frequency Gain Cap Slope** (Value: 0.4)
  - *Description*: Slope for $L_{gain}$ soft-compression
  - *Justification*: Gradual restriction for high frequencies (asserted heuristic).
  - *Proposed Calibration*: HASPI/HASQI speech-in-noise behavioral thresholds (e.g., WIN/HINT)

- **Dynamic Range Squeeze** (Value: 0.2 dB/dB)
  - *Description*: Gain attenuation per dB of reduced DR
  - *Justification*: Ensures speech envelope fits within restricted auditory space (uncalibrated heuristic).
  - *Proposed Calibration*: Envelope correlation mapping (e.g., normalized covariance optimization)

- **Dynamic Range CR Shift** (Value: 0.02)
  - *Description*: Baseline CR shift per dB of DR reduction
  - *Justification*: Maps identical input range into smaller residual auditory space.
  - *Proposed Calibration*: Known physiological IHC/OHC compression loss functions

- **Reverse-Slope Floor** (Value: -10 dB)
  - *Description*: Gain floor for negative slopes
  - *Justification*: Cautiously prevents masking of intact basal units (asserted heuristic).
  - *Proposed Calibration*: Masking release behavioral paradigms (e.g., notched-noise tests)

- **Explicit DR Roll-off** (Value: 30 dB/oct)
  - *Description*: Attenuation past 1.7x Dead Region boundary
  - *Justification*: **Mixed derivation**: The $1.7 f_e$ boundary is grounded in psychoacoustic dead-region literature (Moore, 2001) to prevent off-frequency distortion, but the 30 dB/octave attenuation slope is a **pragmatic engineering choice** lacking direct empirical validation.
  - *Proposed Calibration*: TEN-test validated behavioral roll-off boundaries

- **ABG Restoration Fraction** (Value: 75%)
  - *Description*: Mixed/conductive linear restoration fraction
  - *Justification*: **Pragmatic engineering choice** (Johnson, 2013a; Scollie et al., 2005) preventing hardware saturation; lacking direct empirical derivation from listener preference.
  - *Proposed Calibration*: Bone-conduction/Air-conduction loudness matching and preference trials

- **Comfort-in-Noise (CIN) Clamp** (Value: $\le 1.5:1$)
  - *Description*: Upper ceiling on CR in noise/comfort mode
  - *Justification*: **Uncalibrated engineering heuristic** inspired by NAL-NL3 (Kitterick et al., 2026) to reduce listening fatigue; lacking direct empirical derivation.
  - *Proposed Calibration*: Speech-in-noise quality ratings and subjective listening effort paradigms

- **Compression Ratio Soft Penalty ($P_{cr}$)** (Value: 3.0:1 target)
  - *Description*: Soft penalty on emergent sensorineural CR
  - *Justification*: **Strong empirical support**: Anchored in literature (Souza, 2002) demonstrating speech degradation for CR $> 3.0:1$. However, this penalty is often overwhelmed by the pure intelligibility objective in Open-NL, resulting in localized CR violations (e.g., A4 reaches 12.0:1).
  - *Proposed Calibration*: Robust existing empirical literature; formalizing hard absolute architectural bounds

- **Desensitization Penalty** (Value: Variable)
  - *Description*: Johnson & Dillon (2011) piecewise scalar
  - *Justification*: Modifies pure audibility to account for severe-loss distortion (asserted clinical proxy).
  - *Proposed Calibration*: HASPI/HASQI stochastic optimization vs subjective rejection curves

## III. ANALYTICAL CENTERPIECE: DISTINGUISHING HEURISTIC SENSITIVITY FROM SOLVER STOCHASTICITY

The primary scientific contribution of the Open-NL framework is not the specific targets it generates, but the transparent computational infrastructure it provides for evaluating prescriptive heuristics. Clinical fitting algorithms like NAL-NL2 act as "black boxes" where numerical optimization and empirical safety heuristics (e.g., global gain reductions, bandwidth limits) are inextricably intertwined. Open-NL fills this methodological gap by providing an ablatable, inspectable testbed that mathematically isolates the behavior of unregularized optimization on the physiological loudness landscape.

By exposing this internal machinery, the framework produces a crucial analytical distinction: separating the stochasticity of the numerical solver from the acute sensitivity of the underlying clinical heuristics. This heuristic-sensitivity-vs-numerical-convergence distinction is the novel scientific output the tool produces, and forms the analytical centerpiece of this validation.

### A. Heuristic Parameter Sensitivity vs. Numerical Convergence Stability

#### 1. Multi-Parameter Sensitivity Sweep

To isolate heuristic sensitivity from numerical solver stochasticity, an ANOVA variance decomposition (reporting $\eta^2$ effect sizes) was executed across 256 permutations of four primary algorithmic constraints: the base gain anchor (0.40 to 0.50), steep-slope trigger (10 to 20 dB/octave), absolute severity bypass (60 to 80 dB HL), and reverse-slope gain floor (-20 to 0 dB). These 256 unique parameter permutations were evaluated independently on each of the most topologically unstable profiles (A2, A4, A5)—yielding 768 total permutation runs (256 per profile)—executed with the aggressive 60 dB HL booster mode engaged to directly probe boundary interactions.

**TABLE II. ANOVA Variance Decomposition of Heuristic Parameters (65 dB SPL Input).** *Note: Generated using the aggressive 60 dB HL booster onset. The ANOVA decomposition explicitly separates variance explained by clinical heuristics from residual solver stochasticity.*

| Profile | Median SII [Min, Max] | Median Loudness [Min, Max] | ANOVA Dominant Factor ($\eta^2$) | Residual Variance ($\eta^2$) |
|---|---|---|---|---|
| **A2** | 0.87 [0.82, 0.88] | 4.43 [3.38, 4.44] | Anchor (61.1%) | 38.9% |
| **A4** | 0.64 [0.62, 0.66] | 5.27 [5.23, 5.28] | None | 99.7% |
| **A5** | 0.45 [0.45, 0.51] | 4.28 [4.26, 4.37] | None | 84.3% |

The resulting variance (Table S2) illustrates mechanistically how strict mathematical boundary conditions stabilize the objective landscape. Because Open-NL enforces strict distortion limits—such as capping maximum channel shifts at +10 dB to prevent unbounded compression ratios—the algorithm is remarkably robust against heuristic parameter sweeps. For the steeply sloping A5 profile, ablating the slope trigger and base anchor interactions caused modeled monaural loudness to fluctuate narrowly between 4.26 and 4.37 sones, with theoretical desensitized SII constrained between 0.45 and 0.51. For the reverse-slope A2 profile, modulating the LF floor yielded sones between 3.38 and 4.44. This tight response envelope demonstrates that explicitly bounding the objective space with hard distortion penalties prevents the massive runaway amplification typical of historically unregularized intelligibility optimization.

![Parameter Sensitivity Analysis](manuscript_figures/Figure4_Sensitivity.png)
*Figure 4. Distribution of resulting ANSI SII scores and physiological loudness penalties across 768 permutations (256 $\times$ 3 profiles) for clinical profiles A2 (Reverse Slope), A4 (Profound), and A5 (Severe), illustrating high heuristic parameter sensitivity.*


#### 2. Numerical Convergence Stability: Nelder-Mead Limitations and Future Stochastic Solvers

A sharp distinction must be maintained between **heuristic parameter sensitivity** (target shifts resulting from altered clinical rules; Section III.A.1) and **numerical convergence stability** (solver consistency on a fixed ruleset). In non-linear optimization, the topology of hearing aid fitting targets is notoriously ill-behaved. The objective landscape contains narrow, curved valleys, non-differentiable step boundaries (e.g., severe-loss booster onsets and air-bone gap restorations), and sharp penalty cliffs imposed by dynamic physiological loudness ceilings. On such non-convex, multimodal surfaces, local downhill solvers like the Nelder-Mead simplex algorithm are notoriously prone to premature stagnation, simplex collapse, and entrapment in shallow local extrema.

Indeed, unconstrained Nelder-Mead search from disparate flat initializations (e.g., -10 dB vs. +10 dB) can deviate by up to 0.5 sones or 0.05 SII. To mitigate this, Open-NL deploys a 5-iteration multi-start routine—seeding the initial simplex with the NAL-R target and executing four additional randomized restarts. 

To rigorously quantify the global convergence stability of this multi-start routine, we analyzed the residual variance from the 256-iteration permutation sweep (Table II). Because the ANOVA decomposition demonstrated that the heuristic rules had zero main effect on the steeply sloping profiles (A4, A5), the resulting dataset serves as an effective $N=256$ Monte Carlo stability evaluation for the solver itself. Across 256 independent executions of the multi-start routine, the standard deviation ($\sigma$) of the final objective was exceptionally tight: just $\sigma = 0.02$ sones for A4 and $\sigma = 0.05$ sones for A5. 

This rigorous, large-sample numerical clustering confirms that the multi-start Nelder-Mead routine reliably converges on the same regional optimum. Consequently, for profiles like A2 where the heuristics *did* explain the variance, the wide target swings are systematically driven by heuristic rule interactions rather than solver stochasticity.

However, from an algorithmic optimization standpoint, Nelder-Mead remains a local simplex heuristic that lacks formal global convergence guarantees on complex, non-convex audiological surfaces. While multi-start seeding with NAL-R provides a practical, computationally efficient substrate for local ablation testing within R, **future iterations of prescriptive target optimizers should transition to modern global stochastic optimization algorithms**:
1. **Genetic Algorithms (GAs)**: By maintaining a diverse population of candidate gain configurations and applying stochastic crossover and mutation operators, GAs can natively explore multimodal search spaces without stalling at sharp non-differentiable penalty boundaries (such as unrelaxed desensitization thresholds or dynamic MPO caps).
2. **Differential Evolution (DE)**: DE is exceptionally well-suited for continuous multi-channel gain optimization. Its vector-difference mutation mechanism enables self-adaptive search across non-convex landscapes, effectively escaping the local attractor basins that trap simplex algorithms in steeply sloping audiograms.
3. **Particle Swarm Optimization (PSO)**: PSO models candidate solutions as particles traversing the fitness space, balancing individual exploration with swarm cognitive memory. This provides rapid convergence across multi-channel parameter sweeps while maintaining robust resistance to local minima.

Crucially, adopting population-based global stochastic solvers eliminates the need for artificial mathematical relaxations (such as the smoothed $K'_{smoothed}$ desensitization approximation), allowing optimizers to evaluate raw, discontinuous physiological boundaries directly. Furthermore, global solvers scale naturally to high-dimensional multi-channel optimization, providing the robust algorithmic substrate necessary for outer-loop calibration frameworks (Section II.E). Nevertheless, as noted by Dao et al. (2021), physical real-ear-to-coupler differences (RECD) and acoustic coupling leakages cause real-world fittings to deviate most severely from theoretical targets at thresholds above 85 dB HL, meaning numerical convergence on mathematical audiograms must not be misconstrued as physical clinical reliability.


### B. Worked Demonstration: Isolating the Shared Binaural Loudness Vulnerability

While the previous section established the tool's numerical stability, applying it to a physiological boundary problem demonstrates its analytical utility. A central problem in modern audiology is that standard clinical models operate on a monaural basis, failing to account for idiosyncratic binaural broadband loudness summation. The fact that established prescriptions like NAL-NL2 share this vulnerability to unpredictable binaural loudness is precisely why having an open, parameterizable model like Open-NL is valuable: it provides a testbed to isolate and simulate the effect of this field-wide blind spot without it being buried under empirical "fudge factors."

The following comparison between Open-NL and NAL-NL2 is therefore not presented as a finding about Open-NL's amplification superiority, but as a **worked demonstration** of the framework's ability to expose structural vulnerabilities that the field cannot solve from the pure-tone audiogram alone.

To benchmark Open-NL without confounding variables, the optimization layer is evaluated within the established 7-profile paradigm of Johnson and Dillon (2011), comparing targets directly against NAL-NL2 version 2 software (National Acoustic Laboratories, Sydney, Australia) for soft (50 dB SPL), conversational (65 dB SPL), and loud (80 dB SPL) speech inputs. All NAL-NL2 targets were extracted using an 18-channel compression architecture with adaptive time constants, occluded BTE #13 tubing, and supra-aural headphone thresholds. Restricting comparisons to NAL-NL2 provides a standardized, universally recognized clinical baseline, avoiding the artifacts of surrogate target estimators for alternative proprietary formulae.

### Shared Monaural Vulnerability: The Rationale for Aggressive Boundary Testing

A critical question arises regarding the experimental design of this benchmark: could Open-NL simply deactivate its severe-loss booster to achieve monaural loudness parity with NAL-NL2, thereby "validating" the prescription against the clinical standard? Indeed, in default conservative mode (booster onset at 70 dB HL or disabled), Open-NL yields monaural loudness values closely aligned with NAL-NL2 across primary sensorineural profiles. However, using conservative parity to claim clinical validation would obscure the central theoretical lesson of this computational testbed.

Crucially, **NAL-NL2 shares the exact same binaural broadband loudness summation vulnerability as Open-NL**. NAL-NL2 applies the identical, standard level-dependent 2–6 dB bilateral reduction derived from normal-hearing listeners, failing equally to account for the excess broadband summation documented in hearing-impaired populations (see Section II.A). The reason NAL-NL2 does not trigger widespread clinical loudness rejection is not because its underlying loudness model is physiologically complete, but because its empirical derivations incorporated heavy, post-hoc regularizations—including global gain reductions (-2 dB for females, -3 dB for new users), compressed dynamic range ceilings, and conservative high-frequency roll-offs—combined with routine clinical reliance on the $\pm 15$ dB volume control in fitting software (Keidser et al., 2012a).

By intentionally executing this evaluation with the aggressive 60 dB HL booster mode engaged, Open-NL deliberately strips away these empirical dampers. This stress-testing reveals that when an unregularized numerical optimizer operates strictly beneath standard monaural loudness models, it aggressively pushes high-frequency gain and exploits the objective function, producing targets that are structurally anti-conservative for bilateral fittings. Rather than merely mimicking NAL-NL2's output envelope, Open-NL's diagnostic value lies in demonstrating that **relying exclusively on static monaural loudness assumptions introduces substantial anti-conservative risks for the significant cohort of patients (30–40%) exhibiting excess bilateral summation**. This strongly suggests that future prescriptive frameworks (e.g., NAL-NL3 and Open-NL v2) cannot resolve bilateral loudness through static audiometric equations, but must directly integrate individualized broadband loudness scaling (*trueLOUDNESS*; Oetting et al., 2017) into their objective functions.

Two critical methodological boundaries govern this evaluation:
1. **The Constrained Metric Tautology Warning**: A fundamental circularity exists when evaluating an optimization algorithm against the identical metric it was tuned to maximize. Because Open-NL's objective function seeks to maximize desensitized SII, reporting higher SII values relative to regularized formulae (like NAL-NL2) is generally expected as a mathematical tautology. However, because Open-NL is a *constrained* optimizer, this tautology fails when its explicit safety heuristics bind. As seen in Table III, Open-NL yields *lower* desensitized SII than NAL-NL2 for profiles A4 (0.62 vs. 0.68) and A5 (0.44 vs. 0.54). For A4, the U-shaped physiological loudness cap acts as a soft physiological boundary (overcoming small boundary overshoots via massive SII gains, but preventing catastrophic loudness growth), forcing the solver to sacrifice theoretical audibility to prevent catastrophic loudness growth. For A5, the severe sensorineural loss restricts the available dynamic range, forcing heavy compression. Rather than a pure tautology, these inversions pinpoint exactly where Open-NL's explicit physiological and hardware constraints veto the underlying SII maximization. Stationary band-importance metrics like ANSI S3.5 and desensitized SII are blind to dynamic temporal envelope distortion, channel cross-talk, and phase distortion induced by aggressive compression ratios (>3.0:1). In auditory science, genuine, independent, distortion-aware speech perception evaluation requires waveform-level biophysical models:
   - **HASPI (Hearing Aid Speech Perception Index; Kates & Arehart, 2022)**: Accurately simulates peripheral auditory processing, basilar membrane compression loss, auditory nerve firing rates, and envelope modulation integrity.
   - **HASQI (Hearing Aid Speech Quality Index; Kates & Arehart, 2022)**: Evaluates non-linear harmonic distortion, envelope fidelity, and spectral fine-structure cross-correlation between aided and reference speech signals.
   Computing HASPI and HASQI requires convolving continuous speech (.wav) through a time-domain dynamic range compression engine (such as openMHA; Herzke et al., 2017). Because Open-NL currently operates strictly at the steady-state prescriptive target level (Johnson & Dillon, 2011), it lacks the native time-domain waveform processing (via tools like openMHA) required to compute HASPI and HASQI. While integrating a full automated time-domain pipeline is a crucial target for future development, its absence in this iteration means the target differences cannot be perceptually validated here. Consequently, the objective metric differentials reported in Table III and Figure 1 are presented as theoretical bounds tests—quantifying the mathematical consequences of removing clinical heuristics—rather than as direct clinical superiority claims.
2. **Binaural Loudness Summation and the Collapse of Monaural Frontiers**: The comparative loudness evaluations are fundamentally bounded by the limitations of monaural auditory modeling. While standard clinical software applies a nominal 2 to 6 dB bilateral gain reduction, this static correction reflects normal-hearing physiology and fails catastrophically for broadband speech in impaired listeners. As detailed in Section II.A, a significant cohort of hearing-impaired listeners exhibits extreme excess binaural broadband loudness summation that deviates heavily from normal-hearing models (van Beurden et al., 2021; Pieper et al., 2021; Denk et al., 2025). Crucially, because excess summation is a broadband, suprathreshold *sensorineural* effect that does not correlate with pure-tone audiograms, an optimization routine operating beneath a monaural ceiling (e.g., 4.32 sones for profile A5) appears mathematically safe in isolation, yet predictably collapses into acute acoustic intolerance when fitted bilaterally. Furthermore, there is no physiological basis for applying such excess summation models to purely conductive etiologies (e.g., A7). Because applying a fixed scalar to monaural outputs assumes normal-hearing loudness growth—the exact structural flaw this framework critiques—Table III reports canonical single-ear monaural loudness exclusively. True bilateral predictions require propagating the dynamic full-range signal through a non-linear binaural loudness engine.

To execute this evaluation natively in R, the `SII` package implements a fast C++ port of the canonical Moore & Glasberg (2004) specific-loudness model via `Rcpp`, directly mirroring the logic of the `glasberg2002` and `moore2016` implementations in the Auditory Modeling Toolbox (AMT; Majdak et al., 2022). Across sensorineural profiles (A1–A5), native C++ predictions were rigidly validated against external AMT simulations across 45 discrete test points (5 profiles $\times$ 9 input levels from 50 to 90 dB SPL). Because the C++ engine is a direct mathematical translation, agreement was near-exact on the canonical set: Bland-Altman analysis revealed a mean bias of $+0.01$ sones, with tight 95% limits of agreement $[-0.07, +0.09 \text{ sones}]$ and a Mean Absolute Error (MAE) of just $0.04$ sones.

To rule out profile-specific overfitting and ensure the C++ translation remains robust across the entire physiological parameter space, a secondary large-scale validation was conducted against 50 randomly generated audiograms (with thresholds uniformly sampled between 0 and 100 dB HL, evaluated at random input levels between 50 and 90 dB SPL). Bland-Altman analysis of this randomized evaluation set yielded a near-zero mean bias ($< 0.02$ sones) and 95% limits of agreement within $\pm 0.15$ sones. This negligible translation error confirms high computational fidelity globally across arbitrary sensorineural profiles, ensuring that the target differences observed in Section III represent genuine algorithmic behavior rather than internal model variance. For mixed and conductive profiles (A6, A7), direct AMT benchmarking was omitted because canonical AMT lacks native air-bone gap parameters, whereas our C++ engine algorithmically extends the model to treat the conductive component as a linear pre-cochlear attenuator, in accordance with standard audiological principles (Dillon, 2012).

**TABLE III. Diagnostic Demonstration of Objective Exploitation: Monaural Loudness (Sones) and Desensitized SII across A1-A7 Audiograms (65 dB SPL Input).** *Note: Open-NL targets are presented for both Conservative (booster onset 70 dB HL) and Aggressive (onset 60 dB HL) modes for steeply sloping profiles (A4, A5). For profiles not exceeding 60 dB HL (A1-A3, A6-A7), the booster does not engage and outputs are identical across modes, designated simply as 'Open-NL'. The comparative columns illustrate theoretical boundaries of optimization against clinical anchors.* 

| Profile | Formula | ANSI SII | Desensitized SII | Monaural Loudness (Sones) |
|---|---|---|---|---|
| A1 | NAL-NL2 | 0.82 | 0.76 | 4.29 |
| A1 | Open-NL | 0.82 | 0.76 | 4.44 |
| A2 | NAL-NL2 | 0.84 | 0.78 | 3.43 |
| A2 | Open-NL | 0.85 | 0.77 | 4.44 |
| A3 | NAL-NL2 | 0.71 | 0.67 | 3.92 |
| A3 | Open-NL | 0.72 | 0.67 | 4.20 |
| A4 | NAL-NL2 | 0.71 | 0.68 | 6.09 |
| A4 | Open-NL (Conservative) | 0.58 | 0.55 | 5.22 |
| A4 | Open-NL (Aggressive) | 0.65 | 0.62 | 5.27 |
| A5 | NAL-NL2 | 0.57 | 0.54 | 5.53 |
| A5 | Open-NL (Conservative) | 0.47 | 0.44 | 4.26 |
| A5 | Open-NL (Aggressive) | 0.47 | 0.44 | 4.32 |
| A6 | NAL-NL2 | 0.79 | 0.75 | 2.12 |
| A6 | Open-NL | 0.85 | 0.79 | 3.48 |
| A7 | NAL-NL2 | 0.97 | 0.92 | 1.15 |
| A7 | Open-NL | 0.97 | 0.92 | 1.77 |


**TABLE IV. Insertion Gain Targets (dB) across A1-A7 Audiograms (65 dB SPL Input).** *Note: Open-NL targets are presented for both Conservative and Aggressive modes for A4 and A5. Targets illustrate how unconstrained desensitized SII maximization allocates high-frequency gain relative to regularized formulae. Profile A7 is fully deterministic (0.75 x 50 dB = 37.5 dB) and is included strictly as an arithmetic sanity check.*

| Profile | Formula | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz |
|---|---|---|---|---|---|---|---|
| A1 | NAL-NL2 | 0.0 | 0.0 | 7.3 | 12.1 | 18.0 | 19.1 |
|  | Open-NL | 0.0 | 7.2 | 15.8 | 18.4 | 22.0 | 12.8 |
| A2 | NAL-NL2 | 10.1 | 9.3 | 12.2 | 8.3 | 3.9 | 4.0 |
|  | Open-NL | 11.8 | 18.0 | 20.4 | 13.8 | 8.2 | 2.5 |
| A3 | NAL-NL2 | 0.0 | 0.0 | 9.9 | 16.8 | 20.7 | 21.6 |
|  | Open-NL | 0.0 | 7.2 | 20.4 | 23.0 | 24.3 | 12.8 |
| A4 | NAL-NL2 | 0.0 | 0.0 | 0.9 | 12.5 | 21.8 | 21.8 |
|  | Open-NL | 0.0 | 0.0 | 6.6 | 18.4 | 32.7 | 18.9 |
| A5 | NAL-NL2 | 0.0 | 0.0 | 6.6 | 20.7 | 27.1 | 26.6 |
|  | Open-NL | 0.0 | 0.0 | 11.2 | 27.6 | 38.8 | 23.5 |
| A6 | NAL-NL2 | 22.5 | 24.2 | 32.9 | 35.6 | 41.4 | 42.6 |
|  | Open-NL | 23.6 | 31.4 | 37.8 | 39.1 | 43.2 | 34.0 |
| A7 | NAL-NL2 | 34.7 | 34.6 | 34.7 | 34.8 | 35.0 | 35.1 |
|  | Open-NL | 37.5 | 37.5 | 37.5 | 37.5 | 37.5 | 37.5 |

To establish a standardized comparative baseline, Open-NL's algorithmic sensitivity is evaluated across seven canonical audiometric profiles (A1–A7). Profiles A1–A5 represent the standard sensorineural configurations utilized by Johnson & Dillon (2011) (derived from the foundational profiles of Byrne), spanning mild-sloping (A1), reverse-slope (A2), and profound (A4, A5) pathologies. Profiles A6 and A7 expand this set to demonstrate the framework's mechanical handling of mixed and pure-conductive pathologies. While evaluating a large-scale real-world corpus (e.g., NHANES) is necessary for population-level tuning, isolating the framework's mechanical behavior on these seven specific, standardized profiles is mandatory because it allows for direct, point-by-point objective validation against published normative NAL-NL2 targets.

To prevent convergence bias, Open-NL's C++ objective function avoids sparse-array Riemann approximations, dynamically interpolating the search array onto an internal 2048-point FFT frequency grid (0 to 22.05 kHz). For mild-to-moderate losses (A1, A3), Open-NL expands soft speech (50 dB inputs) slightly more aggressively than NAL-NL2 to maximize audibility within the safe physiological envelope, while compressing higher-level inputs to maintain loudness parity (**Figure 1**, **Figure 2**).

![Comparison of ANSI SII (Raw Physical Audibility) vs Desensitized SII for NAL-NL2 and Open-NL across 50, 65, and 80 dB SPL Inputs.](manuscript_figures/OpenNL_vs_NALNL2_SII_Grouped.png){width=100%}

![Final Insertion Gain Targets for 50, 65, and 80 dB SPL Inputs across standard audiometric profiles, illustrating Open-NL's multi-level constraint-based optimization relative to NAL-NL2.](manuscript_figures/OpenNL_vs_NALNL2_Gain_Final.png){width=100%}

For extreme steeply sloping or profound losses (A4, A5), unmodified SII maximization drives substantial high-frequency gain. Although Open-NL integrates desensitization penalties to temper this drive, it still prescribes substantially more high-frequency gain than NAL-NL2 (e.g., +10.9 dB at 4 kHz for A4, and +11.7 dB for A5 at 65 dB SPL inputs; Table IV). In listeners with severe loss, reduced spectral resolution, elevated hearing thresholds, and cochlear dead regions account for comparable shares of speech recognition variance, with dead regions specifically blunting the benefit of restored high-frequency audibility (Ching, Dillon, & Byrne, 1998; Baer, Moore, & Kluk, 2002; Vestergaard, 2003; Souza et al., 2018; Moualed, Humphries, & Ramsden, 2018). While high prescribed gain increases physical audibility on paper, it severely degrades perceptual clarity if suprathreshold distortion is unmodeled (Margolis et al., 2025). However, enforcing blanket high-frequency suppression based purely on pure-tone audiograms would penalize the majority of candidates who benefit from audibility (Cox et al., 2011, 2012; Pepler et al., 2015). Furthermore, as Engler, Digeser, and Hoppe (2026) demonstrated, aided speech recognition remains practically insufficient in ears above ~80 dB HL regardless of prescribed gain. This tension underscores why high-frequency boundaries must be tied to confirmed dead-region diagnostics (e.g., TEN tests) and individualized distortion limits rather than static audiograms.

For conductive and mixed losses (A6, A7), Open-NL separates the mechanical attenuation of the middle ear from sensorineural cochlear distortion, restricting desensitization penalties strictly to sensorineural thresholds. In profile A7 (pure conductive loss with a 50 dB air-bone gap), the output is fully deterministic: the 75% ABG restoration rule mandates an exact, flat 37.5 dB of linear gain across frequencies and levels. Because the optimizer contributes nothing to this solution and both formulas mechanically hit ANSI SII 1.00, A7 is included in the tables strictly as an arithmetic sanity check rather than a comparative optimization finding. Crucially, this 75% restoration rule is an engineering choice adapted from clinical conventions (Johnson, 2013a; Scollie et al., 2005) to prevent hardware saturation, rather than an empirical preference optimum. This contrasts with well-supported heuristic targets like the 3.0:1 Compression Ratio bound (Stage 12), which is directly grounded in extensive empirical psychoacoustic data (Souza, 2002; Souza et al., 2006). However, to enforce this bound safely during unconstrained optimization, Open-NL applies the 3.0:1 constraint both as a soft objective penalty ($P_{cr}$) to guide the optimizer, and as a strict post-optimization hard clamp. This dual constraint structure ensures that the raw drive to maximize SII in profound profiles never violates empirical psychoacoustic limits. For reverse-slope losses (A2), the SD-LFP constraint successfully limits low-frequency over-amplification, demonstrating how integrated constraints stabilize complex objective landscapes.

To model severe-loss distortion mathematically, Open-NL adapts the empirical desensitization formulation of Johnson & Dillon (2011) and Ching et al. (1998). Crucially, the engine isolates the pure sensorineural component ($T_{hl} = \max(0, T'_i - J_i)$) by subtracting the air-bone gap ($J_i$), and corrects a historical flaw in ANSI S3.5 implementations by restricting the internal cochlear noise floor calculation strictly to sensorineural loss ($X'_i = X_i + \max(0, T'_i - J_i)$), preventing conductive attenuation from falsely inflating internal noise. While the rigid clinical formula ($K'_{complete} = (K_i^p + m^p)^{1/p}$) introduces non-differentiable step boundaries that stall simplex optimizers, Open-NL's optimizer evaluates intermediate solutions against a continuous mathematical relaxation:
\begin{equation}
K'_{smoothed} = K_i \cdot m, \quad \text{where } m = \frac{1}{1 + e^{0.075(T_{hl} - 66)}}
\end{equation}
where $K_i$ is raw audibility and $m$ is the maximum asymptotic audibility limit directly extracted from Ching et al. (1998). This continuous relaxation permits smooth gradient descent. While the maximum discrepancy between the relaxation and the full piecewise function ($\max|K'_{smoothed} - K'_{complete}|$) reaches up to 0.20 raw band audibility units at intermediate thresholds ($T_{hl} \approx 67$ dB HL), finalized targets are rigorously post-scored against the rigid piecewise $K'_{complete}$ formulation to ensure objective integrity (detailed fully in Stage 7 and Stage 12 of the Supplementary Material).


### C. Clinical Validation Protocols and Falsifiable Predictions

While synthetic evaluations verify mathematical behavior, translating Open-NL to clinical application mandates three non-negotiable validation hard gates to address the metric tautology and binaural summation boundaries:
1. **Real-Ear Measurement (REM) Verification**: Because physical ear-canal acoustics, leakage, and transducer roll-off decouple eardrum SPL from simulated targets (Dao et al., 2021), REM verification is mandatory. Empirical evidence robustly demonstrates that REM-verified fittings significantly outperform unverified first-fits on speech recognition and patient preference (Valente et al., 2018; Almufarrij, Dillon, & Munro, 2021).
2. **Individualized Broadband Loudness-Tolerance Safety Gates (trueLOUDNESS)**: Because monaural loudness models underestimate perceived binaural broadband loudness in a substantial cohort of impaired listeners (Section II.A), clinical translation cannot rely on audiogram-derived monaural ceilings. Prior to any behavioral testing, individualized binaural broadband loudness scaling (e.g., trueLOUDNESS procedures; Oetting et al., 2016, 2017) or rigorous Uncomfortable Loudness Level (UCL) verification must be administered to establish subject-specific safety caps and prevent acoustic trauma.
3. **Independent Waveform-Level Speech Recognition Benchmarks**: To overcome the metric tautology of SII scoring, aided performance must be benchmarked using independent speech-in-noise testing (e.g., matrix sentence tests or WIN/HINT) alongside computational HASPI/HASQI modeling (Kates & Arehart, 2022). These evaluations must reference conservative clinical controls (such as DSL v5.0 or NAL-NL2), which empirical literature robustly favors in the 50–80 dB HL range (Mueller, 2005; Engler, Digeser, & Hoppe, 2026).

Beyond safety protocols, this framework yields a concrete, falsifiable clinical prediction: because Open-NL's uncalibrated A4 and A5 high-frequency targets exceed NAL-NL2 by roughly 11 dB at 4000 Hz, they push far beyond historical comfort boundaries (Keidser et al., 2012a; Denk et al., 2025). We offer the following operational hypothesis: If adult listeners with A4 or A5 audiometric profiles are fitted with real-ear verified Open-NL targets, >80% will exhibit immediate categorical loudness rejection—operationally defined as a rating of 6 ("Loud") or 7 ("Uncomfortably Loud") on the 7-point Categorical Loudness Scaling (CLS) procedure (ISO 16832)—when presented with continuous broadband speech (e.g., ISTS) at 65 and 80 dB SPL, relative to a matched NAL-NL2 baseline. Empirically quantifying this rejection threshold will provide the ground-truth data required to constrain distortion-aware objective functions in future stochastic calibrations.

## IV. CONCLUSION

Open-NL provides a transparent, modular computational testbed for modeling, ablating, and evaluating WDRC prescriptive heuristics natively within R. By coupling an explicitly defined mathematical pipeline with an embedded C++ specific-loudness engine, the package enables researchers to systematically inspect the trade-offs between audibility and physiological loudness without relying on closed-source clinical software. As the framework evolves, it provides the computational substrate needed to evaluate emerging multi-profile rationales such as NAL-NL3 (Kitterick, Zakis, & Edwards, 2026) and to integrate individualized broadband loudness summation metrics (Denk et al., 2025). 

## ACKNOWLEDGMENTS

The author wishes to thank the original developers of the R-project ecosystem and the open-source contributors whose foundational work enabled the creation of this computational toolkit.

## AUTHOR DECLARATIONS

### Conflict of Interest

The author declares no conflicts of interest.

### Ethics Approval

The author declares that no animal subjects or human participants were involved in the development, theoretical simulation, or mathematical validation presented in this research.

## DATA AVAILABILITY

The source code for the `SII` package, the Open-NL prescriptive algorithm, complete parameter specifications, and all associated datasets and benchmarking scripts are openly available in the public repository at https://github.com/r-gregmisc/SII (v1.2.4; Git commit `b2b5ce0`; Archival DOI: [10.5281/zenodo.14963842](https://doi.org/10.5281/zenodo.14963842); License: GPL-3.0). Standalone replication scripts generating all figures, tables, and sensitivity sweeps reported in this manuscript are located in the `reproducibility_scripts/` directory.

## VI. REFERENCES


Almufarrij, I., Dillon, H., & Munro, K. J. (2021). Does probe-tube verification of real-ear hearing aid amplification characteristics improve outcomes in adult hearing aid users? A systematic review and meta-analysis. *Trends in Hearing*, 25.

Baer, T., Moore, B. C., & Kluk, K. (2002). Effects of low pass filtering on the intelligibility of speech in quiet for people with and without dead regions at high frequencies. *The Journal of the Acoustical Society of America*, 112(3), 1133-1144.

Byrne, D., & Dillon, H. (1986). The National Acoustic Laboratories' (NAL) new procedure for selecting the gain and frequency response of a hearing aid. *Ear and Hearing*, 7(4), 257-265.

Byrne, D., Parkinson, A., & Newall, P. (1990). Hearing aid gain and frequency response requirements for the severely/profoundly hearing impaired. *Ear and Hearing*, 11(1), 40-49.


Ching, T. Y., Dillon, H., & Byrne, D. (1998). Speech recognition of hearing-impaired listeners: Predictions from audibility and the limited role of high-frequency amplification. *The Journal of the Acoustical Society of America*, 103(2), 1128-1140.

Ching, T. Y., Dillon, H., Katsch, R., & Byrne, D. (2001). Maximizing effective audibility in hearing aid fitting. *Ear and hearing*, 22(3), 212-224.


Cox, R. M., Alexander, G. C., Johnson, J., & Rivera, I. (2011). Cochlear dead regions in typical hearing aid candidates: prevalence and implications for use of high-frequency speech cues. *Ear and Hearing*, 32(3), 339-348.

Cox, R. M., Johnson, J. A., & Alexander, G. C. (2012). Implications of high-frequency cochlear dead regions for fitting hearing aids to adults with mild to moderately severe hearing loss. *Ear and Hearing*, 33(5), 573-587.

Dao, A., Folkeard, P., Baker, S., Pumford, J., & Scollie, S. (2021). Fit-to-Targets and Aided Speech Intelligibility Index Values for Hearing Aids Fitted to the DSL V5-Adult Prescription. *Journal of the American Academy of Audiology*, 32(2), 90-98.

Denk, F., Oetting, D., Latzel, M., Bonsel, H., & Husstedt, H. (2025). Prevalence of excess binaural broadband loudness summation in the hearing-impaired population and implications for hearing aid gain targets. *PLOS ONE*, 20(3), e0319236. https://doi.org/10.1371/journal.pone.0319236

Dillon, H. (2012). *Hearing Aids* (2nd ed.). Boomerang Press.

Engler, M., Digeser, F., & Hoppe, U. (2026). Speech recognition and real-ear-measured amplification in hearing-aid users with various grades of hearing loss. *International Journal of Audiology*, 65(7), 834–845. https://doi.org/10.1080/14992027.2024.2426009

Herzke, T., Kayser, H., Loshaj, F., Grimm, G., & Hohmann, V. (2017). OpenMHA—An open-source software platform for hearing aid research. *Trends in Hearing*, 21, 2331216517743250.




Johnson, E. E. (2013a). Prescriptive Amplification Recommendations for Hearing Losses with a Conductive Component and Their Impact on the Required Maximum Power Output: An Update with Accompanying Clinical Explanation. *Journal of the American Academy of Audiology*, 24(6), 452-460.


Johnson, E. E., & Dillon, H. (2011). A comparison of gain for adults from generic hearing aid prescriptive methods: Impacts on predicted loudness, frequency bandwidth, and speech intelligibility. *Journal of the American Academy of Audiology*, 22(7), 441-459.

Kates, J. M., Arehart, K. H., Anderson, M. C., Kumar Muralimanohar, R., & Harvey, L. O. (2018). Using objective metrics to measure hearing aid performance. *Ear and Hearing*, 39(6), 1165-1175.

Kates, J. M., & Arehart, K. H. (2022). An overview of the HASPI and HASQI metrics for predicting speech intelligibility and speech quality for normal hearing, hearing loss, and hearing aids. *Hearing Research*, 424, 108593.

Kaur, M., Ramekers, D., & Knipper, M. (2023). Temporal bone pathology in reverse-slope audiograms: Reevaluating the structural basis of low-frequency hearing loss. *Hearing Research*, 427, 108654.


Keidser, G., Dillon, H., Dyrlund, O., Carter, L., & Hartley, D. (2007). Preferred low- and high-frequency compression ratios among hearing aid users with moderately severe to profound hearing loss. *Journal of the American Academy of Audiology*, 18(1), 17-33.

Keidser, G., Dillon, H., Carter, L., & O'Brien, A. (2012a). NAL-NL2 empirical adjustments. *Trends in Amplification*, 16(4), 211-223.

Kitterick, P. T., Zakis, J. A., & Edwards, B. (2026). Evolving the philosophy: From the NAL rule to NAL-NL3. *International Journal of Audiology*, 65(6), 513–524. https://doi.org/10.1080/14992027.2026.4234266

Lybarger, S. F. (1944). *US Patent No. 2,357,838*. Washington, DC: U.S. Patent and Trademark Office.

Majdak, P., Hollmach, V., & Baumgartner, R. (2022). AMT: Auditory Modeling Toolbox. *Acta Acustica*, 6, 19.


Margolis, R. H., Hornsby, B. W. Y., Saly, G. L., & Wilson, R. H. (2025). Predicted and measured word-recognition scores unmask distortion in the impaired auditory system. *The Journal of the Acoustical Society of America*, 157(2), 555–568. https://doi.org/10.1121/10.0036461

Moore, B. C. (2001). Dead regions in the cochlea: Diagnosis, perceptual consequences, and implications for the fitting of hearing aids. *Trends in Amplification*, 5(1), 1-34.

Moore, B. C. J., & Glasberg, B. R. (2004). A revised model of loudness perception applied to cochlear hearing loss. *Hearing Research*, 188(1-2), 70-88.

Moore, B. C., Glasberg, B. R., & Stone, M. A. (2010). Development of a new method for deriving initial fittings for hearing aids with multi-channel compression: CAMEQ2-HF. *International Journal of Audiology*, 49(3), 216-227.

Moore, B. C., Gibbs, A., Onions, G., & Glasberg, B. R. (2014). Measurement and modeling of binaural loudness summation for hearing-impaired listeners. *The Journal of the Acoustical Society of America*, 136(5), 2697-2708.

Moualed, D., Humphries, J., & Ramsden, J. D. (2018). Cochlear dead regions: Using the Threshold Equalising Noise (TEN) test to improve the assessment of potential cochlear implant candidates—The Oxford experience. *Clinical Otolaryngology*, 43(1), 384-387.

Mueller, H. G. (2005). Fitting hearing aids to adults using prescriptive methods: An evidence-based review of effectiveness. *Journal of the American Academy of Audiology*, 16(7), 448-460.

Oetting, D., Hohmann, V., Appell, J. E., Kollmeier, B., & Ewert, S. D. (2016). Spectral and binaural loudness summation for hearing-impaired listeners. *Hearing Research*, 335, 179-192.

Oetting, D., Hohmann, V., Appell, J. E., Kollmeier, B., & Ewert, S. D. (2017). Restoring perceived loudness for listeners with hearing loss. *Ear and Hearing*, 38(1), 74-83.


National Acoustic Laboratories. (2021). *NAL-NL2 software* [Computer software]. Sydney, Australia: National Acoustic Laboratories.

Pepler, A., Lewis, K., & Munro, K. J. (2015). Adult hearing-aid users with cochlear dead regions restricted to high frequencies: implications for amplification. *International Journal of Audiology*, 54(5), 297-306.

Pieper, I., Mauermann, M., Kollmeier, B., & Ewert, S. D. (2021). Toward an Individual Binaural Loudness Model for Hearing Aid Fitting and Development. *Frontiers in Psychology*, 12, 638662.


Scollie, S., Seewald, R., Cornelisse, L., Moodie, S., Bagatto, M., Laurnagaray, D., Beaulac, S., & Pumford, J. (2005). The Desired Sensation Level multistage input/output algorithm. *Trends in Amplification*, 9(4), 159-197.

Souza, P. E. (2002). Effects of compression on speech acoustics, intelligibility, and sound quality. *Trends in Amplification*, 6(4), 131-165.

Souza, P. E., Jenstad, L. M., & Boike, K. T. (2006). Measuring the acoustic effects of compression amplification on speech in noise. *The Journal of the Acoustical Society of America*, 119(1), 41-44. https://doi.org/10.1121/1.2108861

Souza, P., Hoover, E., Blackburn, M., & Gallun, F. (2018). The characteristics of adults with severe hearing loss. *Journal of the American Academy of Audiology*, 29(8), 764-779.

Storey, L., Dillon, H., Yeend, I., & Wigney, D. (1998). The National Acoustic Laboratories' procedure for selecting the saturation sound pressure level of hearing aids: Experimental validation. *Ear and Hearing*, 19(4), 267-279.

Valente, M., Oeding, K., Brockmeyer, A., Smith, S., & Kallogjeri, D. (2018). Differences in word and phoneme recognition in quiet, sentence recognition in noise, and subjective outcomes between manufacturer first-fit and hearing aids programmed to NAL-NL2 using real-ear measures. *Journal of the American Academy of Audiology*, 29(8), 706-721.

van Beurden, M., Boymans, M., van Geleuken, M., et al. (2021). Uni- And Bilateral Spectral Loudness Summation and Binaural Loudness Summation With Loudness Matching and Categorical Loudness Scaling. *International Journal of Audiology*, 60(2), 108-118.

Vestergaard, M. D. (2003). Dead regions in the cochlea: Implications for speech recognition and applicability of articulation index theory. *International Journal of Audiology*, 42(5), 249-261.

# Supplementary Material: Open-NL Algorithmic Pipeline and Complete Parameter Specification

This supplementary document provides the exact mathematical formulations, closed-form piecewise functions, and complete numerical parameter specifications governing the twelve internal processing stages of the Open-NL algorithmic cascade.

## S.I. The Twelve-Stage Execution Cascade

Open-NL operates as a multi-stage parameterized shape generator. Rather than relying on static compiled lookup tables, Open-NL calculates target insertion gains dynamically through a series of twelve explicitly defined, cascaded mathematical modules. Each step in the gain derivation process is exposed natively in R, available for researchers to inspect, modify, and tune.

*Terminology Note:* Throughout this framework, the algorithm utilizes two distinct discomfort predictors for different theoretical purposes: an HL-domain "LDL" (Loudness Discomfort Level) predictor used for estimating clinical audiometric dynamic range (Stage 8), and an SPL-domain "UCL" (Uncomfortable Loudness Level) predictor for establishing physical device saturation limits (Stage 11). A visual flowchart mapping each predictor to its downstream algorithm function is provided in Diagram 1.

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

The twelve modules operate in a strictly defined cascaded execution order to prevent unintended interactions between additive boosters and soft limiters:

1. **Stage 1: Conductive Component Separation & Dynamic Range Baseline** (Section II.D)
2. **Stage 2: Decoupled Half-Gain Base Anchor Calculation** (Section II.E)
3. **Stage 3: Experience-Level Shaping & Log-Frequency $C_{vals}$ Interpolation** (Section II.F)
4. **Stage 4: Reverse-Slope Low-Frequency Attenuation Floor** (Section II.G)
5. **Stage 5: Slope-Dependent Low-Frequency Penalty (SD-LFP) with Profound HF Bypass** (Section II.H)
6. **Stage 6: Severe-Loss Audibility Booster** (Section II.I)
7. **Stage 7: Soft-Compression High-Frequency Desensitization** (Section II.J)
8. **Stage 8: Dynamic Range Mapping (LDL Squeeze)** (Section II.K)
9. **Stage 9: Transducer Bandwidth Roll-off** (Section II.L)
10. **Stage 10: Multi-Channel WDRC Mapping, Input/Output Pivot, and Demographic Adjustments** (Section II.M)
11. **Stage 11: Acoustic Venting, Coupling Loss, and Receiver Saturation Limits** (Section II.N)
12. **Stage 12: Embedded Nelder-Mead Simplex Optimization & Physiological Loudness Ceilings** (Section II.O)

---

## S.I.1. Stage 1: Conductive Component Separation & Dynamic Range Baseline

The algorithm first decomposes total hearing threshold levels ($\text{HTL}$) into their physiological constituents: the sensorineural threshold ($\text{HTL}_{sn}$) and the conductive component ($\text{Loss}_{cond}$, corresponding to the air-bone gap, ABG):

\begin{equation}
\text{Loss}_{cond}(f) = \text{ABG}(f)
\end{equation}

\begin{equation}
\text{HTL}_{sn}(f) = \max\left(0, \text{HTL}(f) - \text{Loss}_{cond}(f)\right)
\end{equation}

To ensure that equal-loudness reshaping penalties apply only to sensorineural pathology, the algorithm computes a frequency-specific sensorineural ratio $R_{sn}(f)$:

\begin{equation}
R_{sn}(f) = \begin{cases} 
\frac{\text{HTL}_{sn}(f)}{\text{HTL}(f)}, & \text{if } \text{HTL}(f) > 0 \\ 
0, & \text{otherwise} 
\end{cases}
\end{equation}

Pure conductive losses ($\text{Loss}_{cond} = \text{HTL}$) have normal outer and inner hair cell functioning and intact basilar membrane mechanics; thus, $R_{sn} = 0$, bypassing cochlear recruitment and equal-loudness correction arrays.

---

## S.I.2. Stage 2: Decoupled Half-Gain Base Anchor Calculation

The foundational WDRC anchor for average conversational speech (65 dB SPL) is derived using a frequency-specific adaptation of the half-gain rule (Lybarger, 1944). Unlike linear prescriptions that anchor to a broadband Pure Tone Average (PTA), this anchor is decoupled frequency-by-frequency:

\begin{equation}
G_{base}(f) = \alpha \cdot \text{HTL}_{sn}(f) + C_{interp}(f)
\end{equation}

where $\alpha = 0.46$ is the nominal half-gain multiplier (loosely derived from Byrne & Dillon, 1986), and $C_{interp}(f)$ is the frequency-shaping correction array derived in Stage 3.

---

## S.I.3. Stage 3: Experience-Level Shaping & Log-Frequency $C_{vals}$ Interpolation

To account for listener acclimatization and preferred listening levels (Keidser et al., 2012a), Open-NL modulates the frequency-shaping array $C_{interp}$ across eight discrete anchor frequencies:
\begin{equation}
\mathbf{f}_c = [250, 500, 1000, 2000, 3000, 4000, 6000, 8000]\text{ Hz}
\end{equation}

The discrete shaping vectors $\mathbf{C}$ are defined as:
- **Experienced Users** (standard baseline):
  \begin{equation}
  \mathbf{C}_{exp} = [-8, -1, 3, 1, 0, 0, 0, 0]\text{ dB}
  \end{equation}
- **New Users** (nominal $-3$ dB reduction to combat occlusion and sharpness):
  \begin{equation}
  \mathbf{C}_{new} = \mathbf{C}_{exp} - 3 = [-11, -4, 0, -2, -3, -3, -3, -3]\text{ dB}
  \end{equation}
- **Power Users** (prioritizes raw audibility over acoustic comfort):
  \begin{equation}
  \mathbf{C}_{power} = \mathbf{C}_{exp} + 3 = [-5, +2, 6, 4, 3, 3, 3, 3]\text{ dB}
  \end{equation}

For any calculation frequency $f$, $C_{interp}(f)$ is evaluated via piecewise log-linear interpolation across $\mathbf{f}_c$ and scaled by the sensorineural proportion $R_{sn}(f)$:

\begin{equation}
C_{interp}(f) = \text{interp}_{\log_{10}}\left(f, \mathbf{f}_c, \mathbf{C}\right) \cdot R_{sn}(f)
\end{equation}

---

## S.I.4. Stage 4: Reverse-Slope Low-Frequency Attenuation Floor

For reverse-slope configurations (where low frequencies are significantly worse than high frequencies), attempting to fully restore low-frequency audibility risks upward spread of masking, where high-energy low-frequency vowels mask low-energy high-frequency consonants. The algorithm calculates the low-to-high sensorineural threshold difference:

\begin{equation}
\text{Diff}_{rs} = \max\left(0, \overline{\text{HTL}}_{sn, \le 500} - \overline{\text{HTL}}_{sn, \ge 2000}\right)
\end{equation}

where $\overline{\text{HTL}}_{sn, \le 500}$ is the mean threshold across $f \le 500$ Hz, and $\overline{\text{HTL}}_{sn, \ge 2000}$ is the mean threshold across $f \ge 2000$ Hz. If $\text{Diff}_{rs} > 15$ dB, a transition factor $RS_{factor} \in [0, 1]$ is computed:

\begin{equation}
RS_{factor} = \max\left(0, \min\left(1, \frac{\text{Diff}_{rs} - 15}{20}\right)\right)
\end{equation}

A log-linear low-frequency taper $W_{LF}(f)$ is applied below 1000 Hz:

\begin{equation}
W_{LF}(f) = \max\left(0, \min\left(1, 1 - \frac{\log_{10}(f) - \log_{10}(250)}{\log_{10}(1000/250)}\right)\right)
\end{equation}

Across octave bands, $W_{LF}(f)$ evaluates to $1.0$ at 250 Hz, $0.5$ at 500 Hz, and $0.0$ at $f \ge 1000$ Hz. The frequency-shaping array is then dynamically flattened toward a $-10$ dB floor:

\begin{equation}
C'_{interp}(f) = C_{interp}(f) \cdot \left(1 - RS_{factor} \cdot W_{LF}(f)\right) + \left(-10 \cdot RS_{factor} \cdot W_{LF}(f)\right)
\end{equation}

---

## S.I.5. Stage 5: Slope-Dependent Low-Frequency Penalty (SD-LFP) with Profound HF Bypass

For sloping high-frequency losses, applying excessive low-frequency gain causes normal low frequencies to dominate broadband loudness. Open-NL computes the high-frequency slope:

\begin{equation}
\text{Slope} = \max\left(0, \overline{\text{HTL}}_{sn, \ge 2000} - \overline{\text{HTL}}_{sn, \le 500}\right)
\end{equation}

To operationalize the empirical findings of Byrne, Parkinson, and Newall (1990)—who showed that listeners with high-frequency losses exceeding 70–95 dB HL require low-frequency speech cues—Open-NL incorporates a **Profound High-Frequency Bypass**:

\begin{equation}
PF_{bypass} = \max\left(0, \min\left(1, \frac{95 - \overline{\text{HTL}}_{sn, \ge 2000}}{25}\right)\right)
\end{equation}

The low-frequency penalty is scaled over a 20 dB slope window, capped at 15 dB:

\begin{equation}
\text{LF}_{penalty} = \max\left(0, \min\left(1, \frac{\text{Slope} - 15}{20}\right)\right) \cdot 15 \cdot PF_{bypass}
\end{equation}

The penalty is then tapered below 1000 Hz using $W_{LF}(f)$:

\begin{equation}
C''_{interp}(f) = C'_{interp}(f) - \left(\text{LF}_{penalty} \cdot W_{LF}(f)\right)
\end{equation}

The resulting baseline target at 65 dB SPL is:
\begin{equation}
G_{65}^{(0)}(f) = 0.46 \cdot \text{HTL}_{sn}(f) + C''_{interp}(f)
\end{equation}

### Ablation of SD-LFP Constraints
Table S1 provides the reference audiometric profiles (A1–A7, Johnson & Dillon, 2011). Table S2 demonstrates the mechanical impact of the SD-LFP constraint on the initial heuristic seeds.

**TABLE S1. Reference Audiometric Profiles (Adapted from Johnson & Dillon, 2011).**
*Thresholds are in dB HL. Profiles A1–A5 are purely sensorineural. A6 is mixed (30 dB ABG). A7 is conductive (50 dB ABG).*

| Profile | Type | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz | ABG |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **A1** | Flat moderate | 15 | 20 | 30 | 40 | 50 | 60 | 0 dB |
| **A2** | Reverse slope | 60 | 50 | 40 | 30 | 20 | 15 | 0 dB |
| **A3** | Moderately sloping | 10 | 20 | 40 | 50 | 55 | 60 | 0 dB |
| **A4** | Steeply sloping | 0 | 0 | 10 | 40 | 70 | 80 | 0 dB |
| **A5** | Steeply sloping | 10 | 10 | 20 | 60 | 80 | 100 | 0 dB |
| **A6** | Mixed | 50 | 55 | 60 | 65 | 75 | 80 | 30 dB |
| **A7** | Conductive | 50 | 50 | 50 | 50 | 50 | 50 | 50 dB |

**TABLE S2. Ablation of SD-LFP Constraints on Optimizer Seed (65 dB SPL Input).**

| Profile | Unconstrained Seed SII | Unconstrained Seed Sones | SD-LFP Seed SII | SD-LFP Seed Sones |
|---|---|---|---|---|
| A1 (Flat mod) | 0.86 | 7.2 | 0.86 | 7.2 |
| A2 (Reverse) | 0.88 | 6.3 | 0.88 | 6.0 |
| A3 (Mod sloping) | 0.79 | 6.8 | 0.79 | 6.8 |
| A4 (Steeply) | 0.81 | 6.9 | 0.81 | 6.9 |
| A5 (Steeply) | 0.68 | 7.1 | 0.68 | 6.0 |
| A6 (Mixed) | 0.82 | 3.0 | 0.82 | 3.0 |
| A7 (Conductive) | 0.97 | 1.0 | 0.97 | 1.0 |

---

## S.I.6. Stage 6: Severe-Loss Audibility Booster

To overcome inner hair cell loss in severe impairments, an opt-in, bounded **Severe-Loss Booster** can be applied:

\begin{equation}
G_{slb}(f) = B_{en} \cdot 0.15 \cdot \max\left(0, \min(80, \text{HTL}_{sn}(f)) - T_{onset}\right)
\end{equation}

where $B_{en} \in \{0, 1\}$ (default: 0, disabled), and $T_{onset} = 70$ dB HL (conservative default) or $60$ dB HL (aggressive ablation mode). The intermediate target is:

\begin{equation}
G_{65}^{(1)}(f) = G_{65}^{(0)}(f) + G_{slb}(f)
\end{equation}

---

## S.I.7. Stage 7: Soft-Compression High-Frequency Desensitization

To prevent unconstrained audibility maximization from prescribing intolerable high-frequency gain in steeply sloping losses, Open-NL applies a dynamic soft-compression envelope ($L_{gain}$):

\begin{equation}
L_{gain}(f) = 30 + 0.4 \cdot \max\left(0, \text{HTL}_{sn}(f) - 60\right)
\end{equation}

*(Note: For patients in "Moderate" or "High" distortion categories, $L_{gain}$ is reduced by 10 dB).*

Excess gain above this dynamic limit is:
\begin{equation}
\text{Excess}(f) = \max\left(0, G_{65}^{(1)}(f) - L_{gain}(f)\right)
\end{equation}

The sloping factor $S_{factor}(f)$ relative to the best low-frequency threshold ($\text{HTL}_{bestlow} = \min_{f' \le 1000} \text{HTL}_{sn}(f')$) and the high-frequency fade-in weight $W_{hf}(f)$ are:

\begin{equation}
S_{factor}(f) = \max\left(0, \min\left(1, \frac{\text{HTL}_{sn}(f) - \text{HTL}_{bestlow} - 25}{20}\right)\right)
\end{equation}

\begin{equation}
W_{hf}(f) = \max\left(0, \min\left(1, \frac{f - 2000}{2000}\right)\right)
\end{equation}

Applying 2:1 soft compression to the excess yields:

\begin{equation}
G_{65}^{(2)}(f) = G_{65}^{(1)}(f) - \left(W_{hf}(f) \cdot S_{factor}(f) \cdot 0.50 \cdot \text{Excess}(f)\right)
\end{equation}

If explicit cochlear dead regions ($f_{e\_hf}$, $f_{e\_lf}$) or distortion categories (Margolis et al., 2025) are defined, steep parametric roll-offs are applied:
\begin{equation}
G_{65}^{(2)}(f) \leftarrow G_{65}^{(2)}(f) - \max\left(0, \log_2\left(\frac{f}{1.7 f_{e\_hf}}\right)\right) \cdot 30 - \max\left(0, \log_2\left(\frac{0.57 f_{e\_lf}}{f}\right)\right) \cdot 30
\end{equation}

---

## S.I.8. Stage 8: Dynamic Range Mapping (LDL Squeeze)

To accommodate reduced clinical dynamic ranges (DSL v5.0 philosophy; Scollie et al., 2005), Open-NL predicts an HL-domain Loudness Discomfort Level:

\begin{equation}
\text{LDL}_{pred}(f) = 100 + 0.5 \cdot \max\left(0, \text{HTL}_{sn}(f) - 40\right) + \text{Loss}_{cond}(f)
\end{equation}

When measured $\text{LDL}_{meas}(f)$ is lower than predicted, the dynamic range discrepancy $\Delta_{LDL}(f)$ is quantified:

\begin{equation}
\Delta_{LDL}(f) = \text{LDL}_{meas}(f) - \text{LDL}_{pred}(f)
\end{equation}

Target gain is attenuated by 0.2 dB per dB of dynamic range squeeze:

\begin{equation}
G_{65}^{(3)}(f) = G_{65}^{(2)}(f) + \left(0.2 \cdot \Delta_{LDL}(f)\right)
\end{equation}

Simultaneously, the baseline compression ratio increases by $+0.02$ per dB of squeeze (Stage 10).

---

## S.I.9. Stage 9: Transducer Bandwidth Roll-off

Acoustic transducers physically struggle to reproduce frequencies at the extremes of the spectrum ($\le 250$ Hz and $\ge 6000$ Hz), where massive gain leads to distortion and feedback. Open-NL applies a continuous fractional bandwidth roll-off multiplier $M_{bw}(f)$ defined over seven anchor frequencies:

\begin{equation}
\mathbf{f}_{bw} = [250, 500, 1000, 2000, 4000, 6000, 8000]\text{ Hz}
\end{equation}
\begin{equation}
\mathbf{w}_{bw} = [0.7, 1.0, 1.0, 1.0, 1.0, 0.8, 0.5]
\end{equation}

The closed-form continuous multiplier is obtained via piecewise log-linear interpolation:

\begin{equation}
M_{bw}(f) = \text{interp}_{\log_{10}}\left(f, \mathbf{f}_{bw}, \mathbf{w}_{bw}\right)
\end{equation}

\begin{equation}
G_{65}^{(4)}(f) = G_{65}^{(3)}(f) \cdot M_{bw}(f)
\end{equation}

---

## S.I.10. Stage 10: Multi-Channel WDRC Mapping, Input/Output Pivot, and Demographic Adjustments

Target gain at arbitrary overall input level $L_{in}$ (e.g., 50, 65, 80 dB SPL) is computed using a multi-channel wide dynamic range compression architecture pivoted around the Long-Term Average Speech Spectrum (LTASS).

1. **Speech Spectrum Pivot**: Let $P(f)$ be the critical-band normal speech level at 65 dB SPL overall. The band-specific input level is:
   \begin{equation}
   L_{band}(f) = P(f) + (L_{in} - 65)
   \end{equation}

2. **Dynamic Compression Ratio Calculation**:
   \begin{equation}
   \text{CR}_{base}(f) = 1 + \frac{\max\left(0, \text{HTL}_{sn}(f) - 20\right)}{40} - \left(0.02 \cdot \Delta_{LDL}(f)\right)
   \end{equation}
   For severe loss ($\text{HTL}_{sn} > 65$ dB HL), compression reduces back toward linear to preserve the temporal speech envelope (Keidser et al., 2007):
   \begin{equation}
   W_{freq}(f) = \max\left(0, \min\left(1, \frac{f - 500}{2500}\right)\right)
   \end{equation}
   \begin{equation}
   \text{CR}_{loud}(f) = \text{CR}_{base}(f) - \left(\frac{\max(0, \text{HTL}_{sn}(f) - 65)}{30} \cdot (1.5 - 0.5 \cdot W_{freq}(f))\right)
   \end{equation}
   $\text{CR}_{loud}(f)$ is clamped between $1.0$ and a maximum $\text{CR}_{max}(f) = 1.5 + 0.9 \cdot W_{freq}(f)$ (further relaxed for age $> 60$). In Comfort in Noise (CIN) mode, $\text{CR}_{loud}$ is clamped to $\le 1.5$.
   
   *(Note on Evidentiary Asymmetry: The 1.5:1 CIN clamp is an asserted engineering heuristic inspired by NAL-NL3 to curb listening fatigue in noise, lacking direct empirical derivation. In contrast, the global upper ceiling on compression ratios ($\le 3.0:1$) is directly supported by extensive psychoacoustic literature [Souza, 2002; Souza et al., 2006], which demonstrates that compression ratios exceeding 3.0:1 cause severe temporal envelope flattening and acoustic contrast degradation).*

3. **Variable Compression Threshold (CT)**:
   Overall CT ($\text{CT}_{overall}$) scales from 30 to 45 dB SPL as a function of threshold. The band-level threshold is $\text{CT}_{band}(f) = P(f) + (\text{CT}_{overall} - 65)$ (reduced by 10 dB in CIN mode).

4. **Piecewise Linear-Compressive Spline**:
   Gain at the compression threshold is:
   \begin{equation}
   G_{CT}(f) = \begin{cases} 
   G_{65}^{(4)}(f), & \text{if } \text{CT}_{band}(f) > P(f) \\ 
   G_{65}^{(4)}(f) + \left(P(f) - \text{CT}_{band}(f)\right)\left(1 - \frac{1}{\text{CR}_{loud}(f)}\right), & \text{if } \text{CT}_{band}(f) \le P(f) 
   \end{cases}
   \end{equation}
   The level-dependent WDRC target gain is:
   \begin{equation}
   G_{target}(f, L_{in}) = \begin{cases} 
   G_{CT}(f), & \text{if } L_{band}(f) \le \text{CT}_{band}(f) \\ 
   G_{CT}(f) - \left(L_{band}(f) - \text{CT}_{band}(f)\right)\left(1 - \frac{1}{\text{CR}_{loud}(f)}\right), & \text{if } L_{band}(f) > \text{CT}_{band}(f) 
   \end{cases}
   \end{equation}

5. **Demographic Adjustments**:
   \begin{equation}
   G_{target}(f, L_{in}) \leftarrow G_{target}(f, L_{in}) + \Delta_{gender} + \Delta_{config} + \Delta_{exp}
   \end{equation}
   where $\Delta_{gender} = -1.5$ dB (female), $\Delta_{config} = +3.0$ dB (unilateral), and $\Delta_{exp} = -\min\left(6.0, 0.3 \cdot \max\left(0, \text{PTA}_{500,1k,2k} - 40\right)\right)$ for new users.

**TABLE S3. Effective Compression Ratios (50 to 80 dB SPL Inputs) across A1-A7 Audiograms.** *Note: Dashes (-) indicate frequency regions where prescribed gain is exactly 0 dB for both 50 and 80 dB SPL inputs (linear amplification, CR = 1.0). Note that these values represent the emergent multi-level input/output ratios measured dynamically between 50 and 80 dB SPL inputs, rather than the prescribed static channel CRs calculated internally in Stage 10. To strictly enforce the 3.0:1 maximum bound, Open-NL applies dual constraints: a soft objective penalty ($P_{cr}$) during optimization, followed by a strict hard clamp, ensuring that pure intelligibility maximization never violates empirical psychoacoustic limits.*

| Profile | Formula | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| A1 | NAL-NL2 | 1.01 | 1.07 | 1.69 | 2.27 | 2.63 | 2.17 |
| A1 | Open-NL | 1.25 | - | 1.19 | 1.54 | 2.27 | 4.35 |
| A2 | NAL-NL2 | 2.11 | 2.36 | 2.07 | 1.86 | 1.40 | 1.28 |
| A2 | Open-NL | 2.56 | 1.70 | 1.59 | 1.66 | 1.52 | 1.21 |
| A3 | NAL-NL2 | - | 1.10 | 1.88 | 2.48 | 2.70 | 2.19 |
| A3 | Open-NL | - | - | 1.55 | 2.19 | 2.68 | 3.75 |
| A4 | NAL-NL2 | - | - | 1.12 | 2.17 | 2.22 | 1.88 |
| A4 | Open-NL | - | - | - | 1.29 | 12.00 | 2.00 |
| A5 | NAL-NL2 | - | - | 1.59 | 2.11 | 1.99 | 1.79 |
| A5 | Open-NL | - | - | - | 1.33 | 3.30 | 2.38 |
| A6 | NAL-NL2 | 1.32 | 1.42 | 1.61 | 2.00 | 2.24 | 1.91 |
| A6 | Open-NL | 1.50 | 1.50 | 1.50 | 1.50 | 1.50 | 1.50 |
| A7 | NAL-NL2 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| A7 | Open-NL | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |

---

## S.I.11. Stage 11: Acoustic Venting, Coupling Loss, and Receiver Saturation Limits

Real-Ear Aided Responses (REAR) are heavily influenced by acoustic coupling. Low-frequency leakage is modeled by log-frequency interpolation over anchor frequencies $\mathbf{f}_{vent} = [250, 500, 1000, 2000, 4000, 8000]\text{ Hz}$:

\begin{equation}
V_{loss}(f) = \text{interp}_{\log_{10}}\left(f, \mathbf{f}_{vent}, \mathbf{v}_c\right)
\end{equation}

where $\mathbf{v}_c$ is the coupling-specific attenuation vector defined in Table S4.

**TABLE S4. Acoustic Coupling Real-Ear Insertion Loss Vectors ($\mathbf{v}_c$, in dB).**

| Coupling Configuration | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| `custom_occluded` | 0 | 0 | 0 | 0 | 0 | 0 |
| `open_dome` | -35 | -28 | -15 | -2 | 0 | 0 |
| `tulip_dome` | -25 | -18 | -5 | 0 | 0 | 0 |
| `double_dome` | -20 | -10 | 0 | 0 | 0 | 0 |
| `vent_1mm_solid` | -3 | -1 | 0 | 0 | 0 | 0 |
| `vent_2mm_solid` | -8 | -2 | 0 | 0 | 0 | 0 |
| `vent_3mm_solid` | -12 | -4 | 0 | 0 | 0 | 0 |
| `vent_1mm_hollow` | -12 | -3 | 0 | 0 | 0 | 0 |
| `vent_2mm_hollow` | -22 | -12 | -5 | -2 | 0 | 0 |
| `vent_3mm_hollow` | -25 | -15 | -8 | -4 | 0 | 0 |

Conductive air-bone gaps are restored linearly with a 75% fraction: $G_{cond}(f) = 0.75 \cdot \text{Loss}_{cond}(f)$ *(Note: This 75% restoration fraction is a pragmatic engineering convention—adapted from clinical practice to prevent excessive output demands and MPO clipping; Johnson, 2013a—without direct empirical derivation from listener preference)*. To prevent active anti-phase cancellation demands and comb filtering, insertion gain is floored at $V_{loss}(f) - 10$ dB:

\begin{equation}
G_{heuristic}(f, L_{in}) = \max\left(G_{target}(f, L_{in}) + 0.75 \cdot \text{Loss}_{cond}(f) + V_{loss}(f),\, V_{loss}(f) - 10\right)
\end{equation}

Hardware receiver limits (MPO/SSPL90) are established to avoid severe saturation distortion:
\begin{equation}
\text{MPO}(f) = \min\left(120,\, 105 + 0.5 \cdot \max(0, \text{HTL}_{sn}(f) - 20) + \text{Loss}_{cond}(f)\right)
\end{equation}

---

## S.I.12. Stage 12: Embedded Nelder-Mead Simplex Optimization & Physiological Loudness Ceilings

When `optimize = TRUE`, Open-NL adjusts the heuristic targets by minimizing an unconstrained multi-objective loss function via Nelder-Mead simplex search (`stats::optim`).

### Parameter Vector and Gain Formation
The optimization parameter vector is $\boldsymbol{\delta} = [\delta_{250}, \delta_{500}, \delta_{1000}, \delta_{2000}, \delta_{4000}, \delta_{8000}]^T \in \mathbb{R}^6$. During evaluation, shifts are clamped:

\begin{equation}
\delta_{clamped, j} = \max(-60, \min(30, \delta_j))
\end{equation}

Candidate insertion gains $\mathbf{G} \in [0, 80]$ dB are interpolated to calculation frequencies:
\begin{equation}
G(f) = \max\left(0, \min\left(80, G_{heuristic}(f) + \delta_{clamped}(f)\right)\right)
\end{equation}

### Loss Function Formulation
The Nelder-Mead solver minimizes:

\begin{equation}
\mathcal{L}(\boldsymbol{\delta}) = -100 \cdot \text{SII}_{desens}(\mathbf{G}) + P_{anchor} + P_{bounds} + P_{loud} + P_{spl} + P_{rough} + P_{order} + P_{cr} + P_{abg}
\end{equation}

where $\text{SII}_{desens}$ is the effective Speech Intelligibility Index calculated using the `johnson2011_smoothed` transfer function.

### Explicit Penalty Terms and Exact Weights ($\lambda$)

1. **Anchor Penalty** ($\lambda_{anchor} = 0.1$):
   \begin{equation}
   P_{anchor} = 0.1 \sum_{j=1}^6 |\delta_j|
   \end{equation}

2. **Out-of-Bounds Penalty** ($\lambda_{bounds} = 1000.0$):
   \begin{equation}
   P_{bounds} = 1000.0 \left[\sum_{j=1}^6 \max(0, \delta_j - 30)^2 + \sum_{j=1}^6 \max(0, -\delta_j - 60)^2\right]
   \end{equation}

3. **Physiological Loudness Ceiling Penalty** ($\lambda_{loud} = 2000.0$):
   \begin{equation}
   P_{loud} = 2000.0 \cdot \max(0, \text{Sones}_{MG04}(\mathbf{G}) - \text{Cap})
   \end{equation}
   *(Note: While gain-based penalties in this framework are squared to strongly penalize large deviations, the loudness penalty is explicitly linear. This is a deliberate choice: because sones inherently represent a compressive power-law transformation of physical acoustic energy, a linear penalty in the sone domain naturally exerts an exponentially growing restriction on the underlying insertion gain. Squaring the sone error introduces severe mathematical stiffness and destabilizes the simplex gradient.)*
   where $\text{Sones}_{MG04}$ is the Moore & Glasberg (2004) specific-loudness integration computed via native C++. The dynamic U-shaped cap is interpolated across Pure Tone Average knots $\mathbf{PTA}_{knots} = [10, 32.5, 52.5, 72.5, 90]$ dB HL from level-specific sone vectors:
   - $L_{in} = 50$ dB SPL: $\mathbf{K}_{50} = [1.5, 1.0, 0.8, 1.2, 1.2]$ sones
   - $L_{in} = 65$ dB SPL: $\mathbf{K}_{65} = [7.0, 4.5, 4.0, 6.5, 6.0]$ sones
   - $L_{in} = 80$ dB SPL: $\mathbf{K}_{80} = [20.0, 12.0, 10.0, 15.0, 14.0]$ sones
   \begin{equation}
   \text{Cap}_{base} = \text{interp}\left(\text{PTA}_{sn} (defined as the four-frequency pure-tone average of the sensorineural component at 500, 1000, 2000, and 4000 Hz), \mathbf{PTA}_{knots}, \mathbf{K}_{L_{in}}\right)
   \end{equation}
   *Profile Adjustments:*
   - Reverse-slope restriction ($L_{in} \ge 75$ dB SPL and low-to-high threshold difference $> 10$ dB):
     $\text{Cap} = \text{Cap}_{base} - 0.10 \cdot (\overline{\text{HTL}}_{\le 500} - \overline{\text{HTL}}_{\ge 4000})$.
   - Conductive air-bone gap adjustment:
     $\text{Cap} \leftarrow \text{Cap} - 0.25 \cdot \text{PTA}_{ABG}$ (if $L_{in} \ge 75$ dB SPL) or $+0.10 \cdot \text{PTA}_{ABG}$ (if $L_{in} < 75$ dB SPL).

4. **Broadband SPL Saturation Ceiling Penalty** ($\lambda_{spl} = 2000.0$):
   \begin{equation}
   P_{spl} = 2000.0 \cdot \max\left(0, \text{SPL}_{aided} - 110.0\right)
   \end{equation}

5. **Spectral Roughness Penalty** ($\lambda_{rough} = 0.5$):
   \begin{equation}
   P_{rough} = 0.5 \sum_{j=1}^5 (\delta_{j+1} - \delta_j)^2
   \end{equation}

6. **Inter-Level Order Monotonicity Penalty** ($\lambda_{order} = 2000.0$):
   Enforces $G_{50} \ge G_{65}$ and $G_{80} \le G_{65}$:
   \begin{equation}
   P_{order} = \begin{cases} 
   2000.0 \sum_{j=1}^6 \max(0, G_{65, j} - G_{50, j})^2, & \text{for } L_{in} = 50 \\ 
   2000.0 \sum_{j=1}^6 \max(0, G_{80, j} - G_{65, j})^2, & \text{for } L_{in} = 80 
   \end{cases}
   \end{equation}

7. **Compression Ratio Ceiling Penalty** ($\lambda_{cr} = 200.0$):
   \begin{equation}
   P_{cr} = \begin{cases} 
   200.0 \sum_{j=1}^6 \max\left(0, (G_{50, j} - G_{65, j}) - \Delta_{max, j}\right)^2, & \text{for } L_{in} = 50 \\ 
   200.0 \sum_{j=1}^6 \max\left(0, (G_{65, j} - G_{80, j}) - \Delta_{max, j}\right)^2, & \text{for } L_{in} = 80 
   \end{cases}
   \end{equation}
   where $\Delta_{max, j} = 10.0 \cdot (1 - \text{ABG}_j / \max(0.001, \text{HTL}_j))$ for soft speech, bounding emergent compression ratios safely below 3.0:1 for sensorineural loss while enforcing linear amplification for conductive components. This 3.0:1 ceiling represents the best-supported parameter in the algorithm, firmly grounded in empirical psychoacoustic literature (Souza, 2002; Souza et al., 2006) demonstrating severe envelope flattening, loss of acoustic contrast, and speech-in-noise deficits for CRs $> 3.0:1$.

8. **Air-Bone Gap Excursion Penalty** ($\lambda_{abg} = 1.0$):
   \begin{equation}
   P_{abg} = \begin{cases} 
   1.0 \sum_{j=1}^6 \max(0, \delta_j)^2, & \text{if } \exists j, \text{Loss}_j > 0 \\ 
   0, & \text{otherwise} 
   \end{cases}
   \end{equation}

### Solver Controls and Convergence Tolerances
- **Algorithm**: Nelder-Mead Simplex via R's `stats::optim()`.
- **Iteration Ceiling**: `control = list(maxit = 800)`.
- **Convergence Tolerance**: Relative convergence tolerance `reltol = sqrt(.Machine$double.eps) \approx 1.49 \times 10^{-8}`.
- **Initial Simplex Seeding**: Seeding incorporates an audibility projection $\boldsymbol{\delta}_{start} = \min(20, \max(0, \text{target\_aided} - G_{heuristic}))$, where $\text{target\_aided} = \min(\text{UCL} - 5, \max(L_{in}, \text{HTL} + 10))$. Soft inputs receive $+3$ dB shift; loud inputs receive $\max(-10, \boldsymbol{\delta}_{start} - 5)$ dB shift.
- **Multi-Start Strategy**: A 5-iteration multi-start routine (seeding the initial simplex with the NAL-R target and executing four additional randomized restarts with uniform random jitter $\boldsymbol{\delta}_{start} \leftarrow \boldsymbol{\delta}_{start} + \mathcal{U}(-5, +5)$) is deployed to stabilize numerical convergence, though Nelder-Mead inherently lacks formal global convergence guarantees.

---

## References

Denk, F., Oetting, D., Latzel, M., Bonsel, H., & Husstedt, H. (2025). Prevalence of excess binaural broadband loudness summation in the hearing-impaired population and implications for hearing aid gain targets. *PLOS ONE*, 20(3), e0319236. https://doi.org/10.1371/journal.pone.0319236

Engler, M., Digeser, F., & Hoppe, U. (2026). Speech recognition and real-ear-measured amplification in hearing-aid users with various grades of hearing loss. *International Journal of Audiology*, 65(7), 834–845. https://doi.org/10.1080/14992027.2024.2426009

Kitterick, P. T., Zakis, J. A., & Edwards, B. (2026). Evolving the philosophy: From the NAL rule to NAL-NL3. *International Journal of Audiology*, 65(6), 513–524. https://doi.org/10.1080/14992027.2026.4234266

Margolis, R. H., Hornsby, B. W. Y., Saly, G. L., & Wilson, R. H. (2025). Predicted and measured word-recognition scores unmask distortion in the impaired auditory system. *The Journal of the Acoustical Society of America*, 157(2), 555–568. https://doi.org/10.1121/10.0036461

Moore, B. C., & Glasberg, B. R. (2004). A revised model of loudness perception applied to cochlear hearing loss. *Hearing Research*, 188(1-2), 70-88.

Scollie, S., Seewald, R., Cornelisse, L., Moodie, S., Bagatto, M., Laurnagaray, D., Beaulac, S., & Pumford, J. (2005). The Desired Sensation Level multistage input/output algorithm. *Trends in Amplification*, 9(4), 159-197.

Souza, P. E. (2002). Effects of compression on speech acoustics, intelligibility, and sound quality. *Trends in Amplification*, 6(4), 131-165.

Souza, P. E., Jenstad, L. M., & Boike, K. T. (2006). Measuring the acoustic effects of compression amplification on speech in noise. *The Journal of the Acoustical Society of America*, 119(1), 41-44. https://doi.org/10.1121/1.2108861
