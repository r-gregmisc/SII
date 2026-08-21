---
title: "Open-NL: A Transparent Computational Heuristic for Wide Dynamic Range Compression"
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
**Open-NL**, an open-source prescriptive algorithm, derives dynamic Wide Dynamic Range Compression (WDRC) targets in R. While the derivations of major algorithms like NAL-NL2 are published in detail, their compiled software implementations are closed-source, preventing researchers from testing component-level hypotheses. Open-NL provides a modifiable substrate permitting component-level ablation of prescriptive rules. It utilizes a Slope-Dependent Low-Frequency Penalty (SD-LFP) that scales gain based on threshold severity, applying a mathematically defined low-frequency attenuation to steeply sloping audiograms to constrain excessive modeled loudness growth. Across its internal heuristic evaluations, Open-NL's SD-LFP mathematically constrains modeled loudness growth strictly relative to unconstrained internal ablations (though not necessarily below established clinical baselines like NAL-NL2). Additionally, its experimental severe-loss booster intentionally utilizes a lower gain-increase breakpoint than supported by the audiological literature, functioning explicitly as a hypothesis-generating heuristic expected to over-prescribe relative to current clinical evidence. The framework is strictly a computational toolkit designed for researchers to model and modify insertion gain dynamics, and it has not undergone behavioral validation for clinical use.

## I. INTRODUCTION

Manufacturer-agnostic prescriptions remain central to evidence-based hearing aid practice. While some earlier studies suggested these generic targets might outperform proprietary first-fit algorithms on patient preference and specific metrics (Valente et al., 2018), contemporary data demonstrates that measured speech recognition often shows no significant difference between formulas. Yet, while formula choice has relatively modest intelligibility consequences in background noise, it drives massive variations in overall loudness, making loudness the most informative dependent variable in prescriptive evaluation (Ching et al., 2013).

While the derivations and optimization objectives of major algorithms like NAL-NL2 and DSL m[i/o] are published in detail, their compiled software implementations are closed-source. The defensible gap is not a hidden rationale, but rather the modifiability and reproducibility of the implementation. This lack of modifiability prevents researchers from testing component-level hypotheses; an investigator cannot isolate a specific prescriptive parameter (like high-frequency gain for severe loss) and observe the resulting modeled cascade without reverse-engineering the entire proprietary engine. The clinical utility of algorithmic transparency and alternative, modular rule sets is increasingly recognized; for example, the evolving NAL-NL3 protocol explicitly introduces alternative philosophical profiles designed for specific situational or cohort needs (Kitterick et al., 2026).

Open-NL provides a parameterized, inspectable research testbed conceptually aligned with this evolving philosophy of modular optimization. It is designed as a modular substrate permitting component-level ablation of prescriptive rules, where individual heuristic components—such as slope-dependent penalties or severe-loss boosters—can be independently toggled and their modeled consequences directly measured. 

## II. ALGORITHM ARCHITECTURE

### A. Methods and Development

The core ANSI SII calculation engine (specifically the `sii()` function and its associated plotting methods) was originally developed by Gregory R. Warnes for the archived version of the package. Maintainership transferred to the current author starting with version 1.1.0, at which point all subsequent Open-NL prescriptive logic, clinical heuristics, and WDRC mathematical implementations—including the `open_nl()`, `calculate_loudness()`, and `launch_app()` functions—were independently developed by the current author as original contributions. The theoretical framework, prescriptive rulesets, and experimental design were conceived and executed solely by the author. During the drafting of this manuscript and the optimization of the open-source implementation, Google Gemini Pro 3.1 was utilized as an interactive programming assistant and language tool to aid in code refactoring and typesetting into JASA standards. The author reviewed all output and takes full responsibility for the final algorithms and manuscript content.

### B. Execution cascade

Open-NL operates as a multi-stage parameterized shape generator. Rather than relying on static compiled lookup tables, Open-NL calculates target insertion gains dynamically through a series of explicitly defined cascaded mathematical modules. Each step in the gain derivation process is exposed natively in R, available for researchers to inspect, modify, and tune.

*Terminology Note:* Throughout this manuscript, the algorithm utilizes two distinct discomfort predictors for different theoretical purposes: an HL-domain "LDL" (Loudness Discomfort Level) predictor used for estimating clinical audiometric dynamic range, and an SPL-domain "UCL" (Uncomfortable Loudness Level) predictor for establishing physical device saturation limits. A visual flowchart mapping each predictor to its downstream algorithm function is provided in Diagram 1.

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

The modules described below are not applied simultaneously; rather, they operate in a strictly defined cascaded execution order to prevent unintended interactions between additive boosters and soft limiters. The execution order is as follows:

1. Determine decouple anchor, base multiplier, and severe-loss booster based on Experience level (Section II.C and II.F).
2. Apply Slope-Dependent Low-Frequency Penalty (Section II.D).
3. Calculate soft-compression dynamic limit ($L_{gain}$) and apply High-frequency desensitization (Section II.G).
4. Apply Dynamic Range Mapping (LDL Squeeze) (Section II.H).
5. Apply Transducer Bandwidth Roll-off (Section II.I).
6. Calculate dynamic Compression Ratios (CR) based on thresholds (Section II.J).
7. Integrate Conductive Component correction (+75% ABG) if applicable (Section II.K).
9. Apply MPO-domain saturation limit to ensure output safety.
10. Apply Comfort in Noise (CIN) WDRC alterations if triggered (Section II.L).
11. Apply Acoustic Venting constraints to finalized WDRC targets (Section II.M).
12. Finally, subtract age-specific RECD scaling penalties for infants (Section II.N).

### C. The decoupled anchor and experience level tuning

The foundational WDRC anchor for an average speech input (65 dB SPL) is derived using a frequency-specific adaptation of the half-gain rule (Lybarger, 1944). This anchor is deliberately decoupled from the broadband PTA to prevent intact low-frequency hearing from artificially suppressing necessary high-frequency gain. Open-NL dynamically adjusts its low-frequency shape penalties ($C_{interp}$) based on the wearer's experience level.

Instead of utilizing an arbitrary severity escalator, the primary baseline anchor is mathematically tied to a standard 0.46 half-gain scaling function (Byrne & Dillon, 1986). An optional, bounded severe-loss booster (slope = 0.15) can be linearly applied to thresholds between 60 dB HL and 80 dB HL. This gently assists profound losses with audibility without triggering explosive recruitment when explicitly enabled.

\begin{equation}
G_{base} = 0.46 \cdot \text{HTL}_{sn} + B_{en} \cdot 0.15 \cdot \max(0, \min(80, \text{HTL}_{sn}) - 60) + C_{interp}
\end{equation}
where $\text{HTL}_{sn}$ is the sensorineural component of the Hearing Threshold Level (in dB HL), and $B_{en}$ is a binary toggle (default 0) that explicitly gates the severe-loss booster.

The 0.46 boundary is an explicitly chosen heuristic anchor. The justification chain spans from the classical Lybarger half-gain rule to Berger et al. (1980) demonstrating that obtained gain in mild losses is frequently somewhat less than half. Leijon (1991) and Leijon et al. (1991) further argue that obtained or preferred gain is frequently well below half—Leijon's loudness-density model yields only 25–30% of threshold for mild-to-moderate loss. Consequently, while 0.46 is mathematically positioned near the midpoint, it must be acknowledged that a large body of the preferred prescriptive range sits below 0.46 rather than symmetrically around it.

Consequently, while Keidser et al. (2012) found empirically that new users prefer slightly less gain (with the reduction increasing with degree of loss), Open-NL integrates this preference directly via the frequency-shaping $C_{vals}$ array rather than dynamically collapsing the base multiplier. Open-NL also applies static, simplified heuristic constants to approximate the empirical adjustments for sex and bilateral-fitting interactions reported by Keidser et al. (2012). It should be noted that while the published NAL-NL2 framework utilizes a ±1 dB sex-based gain deviation from baseline (a 2 dB total spread) and a level-dependent bilateral gain reduction (ranging from 2 dB at low inputs to 6 dB at high inputs), Open-NL implements these as simplified static constants: reducing target gain by a flat 1.5 dB as a sex-based gain adjustment. This adjustment functions strictly as a population-mean heuristic reflecting aggregated preference data, not as a rigid individual prescription rule. Open-NL also increases target gain by a flat 3 dB for unilateral fittings to compensate for the lack of binaural loudness summation. The algorithm's omission of explicit binaural broadband summation modeling must be emphasized as a source of systematic deviation; as demonstrated by Denk et al. (2025), excess binaural broadband summation is prevalent in approximately 40% of hearing-impaired listeners. Because Open-NL relies on these simplified static constants, it acts as a heuristic approximation that will systematically diverge from level-dependent frameworks like NAL-NL2, particularly at high input levels where binaural summation effects become non-linear.

The parameters are explicitly defined as follows. $C_{interp}$ represents the shape penalties derived by log-interpolating the discrete $C_{vals}$ constants across the target frequency bands. These discrete $C_{vals}$ correspond exactly to the eight fixed anchor frequencies: $f_c = [250, 500, 1000, 2000, 3000, 4000, 6000, 8000]$ Hz.
1. **New Users**: In accordance with Keidser et al. (2012), who demonstrated that naive users prefer less overall amplification to combat occlusion and high-frequency sharpness, this configuration applies a global ~3 dB reduction from the experienced baseline ($C_{vals} = [-11, -4, 0, -2, -3, -3, -3, -3]$).
2. **Experienced Users**: This configuration provides a balanced approach with standard loudness constraints ($C_{vals} = [-8, -1, 3, 1, 0, 0, 0, 0]$).

### D. Slope-Dependent Low-Frequency Penalty (SD-LFP)

Standard linear formulas, such as NAL-R (Byrne & Dillon, 1986), often cause overprescription or underprescription because they do not systematically account for loudness density scaling across different audiometric slopes. For example, applying massive high-frequency gain to a steeply sloping audiogram forces the functionally normal low frequencies to dominate overall loudness, resulting in catastrophic loudness recruitment. Conversely, applying arbitrary low-frequency penalties to severe flat losses inherently starves them of audibility.

To address this without resorting to a closed-source implementation, Open-NL implements a unified Slope-Dependent Low-Frequency Penalty (SD-LFP). The heuristic leverages a Slope-Dependent Penalty that suppresses low-frequency gain strictly based on the slope of the audiogram:
\begin{equation}
\text{Slope} = \max(0, \text{PTA}_{HF} - \text{PTA}_{LF})
\end{equation}
where $\text{PTA}_{HF}$ is the mean sensorineural threshold for frequencies $\ge 2000$ Hz, and $\text{PTA}_{LF}$ is the mean sensorineural threshold for frequencies $\le 1000$ Hz.

For steeply sloping high-frequency losses (where the slope exceeds 15 dB), Open-NL aggressively penalizes low-frequency gain (by up to 15 dB) to kill the loudness dominance of the normal lows, maintaining the overall loudness budget.
\begin{equation}
\text{LF}_{penalty} = \max\left(0, \min\left(1, \frac{\text{Slope} - 15}{20}\right)\right) \cdot 15
\end{equation}

This penalty is log-linearly tapered for frequencies ($f$) below 1000 Hz and subtracted from the base gain. Across the standard prescriptive frequency bands evaluated ($f_c = [250, 500, 1000, 2000, 3000, 4000, 6000, 8000]$ Hz), this log-taper evaluates to exactly $1.0$ (100% penalty) at $f = 250$ Hz, $0.5$ (50% penalty) at $f = 500$ Hz, and $0.0$ at $f \ge 1000$ Hz:
\begin{equation}
G_{65} = G_{base} - \left(\text{LF}_{penalty} \cdot \max\left(0, 1 - \frac{\log_{10}(f) - \log_{10}(250)}{\log_{10}(1000/250)}\right)\right)
\end{equation}

Crucially, for flat audiograms (where the slope is less than 15 dB), this entire penalty zeroes out. This ensures that severe flat losses retain their full targeted gain without experiencing unnecessary downward compression in the low frequencies.

For reverse-slope configurations (where the low-frequency thresholds are significantly worse than the high frequencies), an inverse logic is applied. Amplifying low frequencies aggressively in these cases may degrade intelligibility if apical sensory units are extensively dysfunctional (Halpin et al., 1994). Furthermore, upward spread of masking from heavily amplified low frequencies can theoretically obscure intact basal units that provide the bulk of speech information (Van Tasell & Turner, 1984). While these single-case and small-sample reports provide directional support for a cautious approach, they do not establish a universal physiological mandate. Indeed, recent temporal-bone analyses demonstrate that audiogram slope is a surprisingly poor proxy for underlying strial versus hair-cell pathology, complicating any simple inferences from slope to physiological substrate (Kaur et al., 2023). Consequently, the specific -10 dB gain floor implemented in Open-NL remains an asserted, conservative heuristic rather than a validated biological necessity. Open-NL suppresses the low-frequency correction array ($C_{interp}$) to this flat -10 dB floor, employing a transitional factor ($RS_{factor}$) for signed slopes exceeding -15 dB:
\begin{equation}
\text{Slope}_{signed} = \text{PTA}_{HF} - \text{PTA}_{LF}
\end{equation}
where $\text{Slope}_{signed}$ drops the zero-floor utilized in Equation 2, permitting negative values to mathematically capture reverse-slope audiograms.
\begin{equation}
RS_{factor} = \max\left(0, \min\left(1, \frac{-\text{Slope}_{signed} - 15}{20}\right)\right)
\end{equation}
\begin{equation}
C'_{interp(f)} = C_{interp(f)} \cdot (1 - RS_{factor} \cdot W_{LF}) + (-10 \cdot RS_{factor} \cdot W_{LF})
\end{equation}
where $C'_{interp(f)}$ is the revised correction array across all frequencies, and $W_{LF}$ is the identical bounded log-linear taper isolated from Equation 4 ($\max(0, 1 - \frac{\log_{10}(f) - \log_{10}(250)}{\log_{10}(1000/250)}$). This dynamically flattens the baseline correction to $-10$ dB strictly in the low frequencies—applying the full $-10$ dB replacement at $f = 250$ Hz, a 50% blend at $f = 500$ Hz, and reverting completely to the unmodified $C_{interp}$ array by $f = 1000$ Hz.

### E. Ablation Analysis: The Mechanism of Steep-Slope Recruitment Constraints

The prevention of severe recruitment in steeply sloping audiograms (such as the standard NAL A5 profile, part of a seven-profile framework adapted from Johnson & Dillon, 2011; originally defined by Byrne et al., 2001) requires explicit mechanism analysis. When the optimization engine is left unconstrained to strictly maximize SII without loudness boundaries, it pumps significant amplification into the low frequencies where the A5 profile has relatively normal thresholds. Table I demonstrates this ablation.

**TABLE I. Ablation of Engine Loudness Constraints and Low-Frequency Penalties (65 dB SPL Input).**

| Ablation Variant | Description | Target SII | Hybrid Sones | Mean Gain |
|---|---|---|---|---|
| No Penalty | Unconstrained SII maximization | 0.99 | 15.3 | 48.7 dB |
| Broadband Penalty | Single scalar loudness cap | 0.61 | 5.2 | 22.1 dB |
| Open-NL (SD-LFP) | Full cascade SD-LFP with frequency-specific shaping | 0.67 | 1.8 | 16.8 dB |

For steeply sloping profiles like A5, removing the engine's dynamic loudness constraints allows the algorithm to aggressively pursue SII by applying unconstrained low-frequency gain. Within the Moore & Glasberg computational framework, which models severe OHC loss in adjacent high frequencies as highly linear (recruiting), this excess low-frequency energy theoretically spreads upward, illustrating a potential disproportionate loudness growth (15.3 sones vs 1.8 sones) for some theoretical intelligibility improvement (0.99 vs 0.67 SII) that is clinically unrealistic due to dead regions. This ablation illustrates that the engine's behavior aligns with physiological models predicting massive recruitment when applying broad-band gain without steep-slope low-frequency penalties (Hornsby et al.). To prevent this, Open-NL relies on its baseline heuristics (which natively restrict low-frequency gain) acting in tandem with the explicit SD-LFP constraint to anchor the target securely. 

Furthermore, this mathematical constraint introduces a genuine evidence–design tension for severely impaired listeners. While the SD-LFP actively suppresses low-frequency gain in steep configurations to prevent modeled loudness recruitment, historical literature demonstrates that a substantial proportion of severely/profoundly impaired listeners explicitly prefer more low-frequency emphasis than standard NAL prescriptions provide (Byrne, Parkinson, & Newall, 1990). Convery and Keidser (2011) also confirmed this preference for higher-low/lower-high frequency responses in this specific population. Because the Open-NL SD-LFP initially triggered strictly on audiometric slope rather than absolute low-frequency severity, a steeply sloping severe loss could be reflexively penalized in precisely the low-frequency region that these listeners rely upon and prefer. To reconcile this tension, Open-NL explicitly gates the SD-LFP by absolute low-frequency severity—bypassing the penalty entirely if low-frequency PTA exceeds 70 dB HL. This allows the algorithm to safely provide the low-frequency emphasis required by severe-to-profound listeners without abandoning the recruitment constraint for mild-to-moderate sloping profiles (such as the A5 profile evaluated here).

However, because this isolated ablation relies on a single simulated profile (A5) without behavioral validation, and since audiometric slope is an imperfect proxy for underlying cochlear pathology (Kaur et al., 2023), these mechanistic outcomes should be interpreted strictly as computational illustrations rather than confirmed clinical consequences. (Note that the 0.67 hybrid SII and 1.8 hybrid sones reported in this isolated ablation translate to the final 0.79 canonical SII and 7.07 canonical sones reported for the full Open-NL cascade in Table IV. This 7.07 sone output is actually slightly lower than the NAL-NL2 canonical baseline of 7.55 sones; thus, the SD-LFP heavily constrains loudness relative to unconstrained algorithmic behavior, though across all profiles, it does not necessarily keep loudness below established clinical baselines like NAL-NL2).

### F. The severe-loss booster

Because foundational half-gain rules mathematically under-amplify severe-to-profound losses with regard to pure audibility, Open-NL incorporates a parameterized **Severe-Loss Booster**. While some literature hypothesizes that severe-to-profound losses require more gain to overcome inner hair cell damage, the precise transition point and magnitude are actively debated. Byrne, Parkinson, and Newall (1990) place the half-gain breakdown transition closer to 70 dB HL, noting that preferred gain typically exceeds the NAL prescription only when high-frequency thresholds approach 95 dB HL. Furthermore, Mueller's (2005) evidence-based review found no studies supporting gain levels structurally higher than the NAL-R/NAL-RP prescriptions. Additionally, Convery and Keidser (2011) demonstrate that experienced severe-to-profound users often prefer their own lower-high-frequency, higher-low-frequency responses over structured prescriptive targets like NAL-RP, and that transitioning them toward prescriptive targets objectively worsened speech discrimination. Indeed, Keidser et al. (2012) observed that people with severe/profound loss preferred lower compression, and that new users prefer progressively less gain as loss increases. However, this historical consensus is complicated by recent contemporary data: Engler et al. (2026) demonstrated that for hearing losses between 50 and 80 dB HL, targeting higher-gain DSL v5.0 values actually optimized aided speech recognition, whereas below 50 dB HL both NAL-NL2 and DSL were comparable, and above 80 dB HL aided recognition was structurally insufficient regardless of the prescription. Consequently, the specific Open-NL implementation introduces a severe-loss booster (a bounded 0.15 slope boost for thresholds between 60 dB HL and 80 dB HL). Because a booster that starts 10 dB below the primary-literature transition (Byrne, Parkinson, & Newall, 1990) is explicitly expected to over-prescribe relative to current clinical evidence, it is framed extremely cautiously and is mathematically gated off by default in the software implementation. When explicitly enabled by researchers, the booster's 60 dB HL onset intersects the 50–80 dB HL window identified by Engler et al. (2026) where targets meeting or modestly exceeding DSL v5.0 values yielded measurable intelligibility benefits. Crucially, aligning with Engler et al.'s findings that aided recognition becomes structurally insufficient above 80 dB HL, and acknowledging the strong evidence from Convery & Keidser (2011) and Keidser et al. (2012) against excessive gain in profound populations, the booster is explicitly capped at 80 dB HL. This bounding prevents the algorithm from linearly escalating into the profound range, where it would otherwise risk over-prescribing and worsening speech discrimination. To prevent discontinuous gain jumps during calculation, this bounded booster is integrated seamlessly into the base target gain formula (see Equation 1, Section II.C).

### G. Soft-compression high-frequency desensitization

Rather than applying a harsh, jagged hard-cap on insertion gain—which may induce spectral artifacts—Open-NL utilizes a smooth soft-compression envelope for high-frequency desensitization. The philosophy of limiting high-frequency gain in severe loss is well-supported (Ching, Dillon, & Byrne, 1998), but the literature is not unidirectional. For instance, Horwitz, Ahlstrom, and Dubno (2008) observed that speech recognition generally increased with added high-frequency bands, finding no evidence of a severity threshold above which amplification became counterproductive. Conversely, evidence demonstrates that the benefit of high-frequency amplification is highly configuration-dependent: while flat losses often benefit significantly, high-frequency gain can be actively counterproductive for steeply sloping configurations (Plyler & Fleck, 2006; Hornsby, Johnson, & Picou, 2011). Because Open-NL currently lacks a configuration-aware switch to dynamically distinguish flat versus sloping pathologies, it adopts a generalized soft constraint to conservatively manage upward spread of masking and distortion in severe impairments. A dynamic gain limit ($L_{gain}$) is established using a 30 dB base and a 0.4 slope. Similar to the 0.46 base scaling factor and the 75% ABG restoration fraction, these constants are asserted heuristics—they are uncalibrated mathematical design choices intended to bind the optimizer rather than validated physiological limits:
\begin{equation}
L_{gain} = 30 + 0.4 \cdot \max\left(0, \text{HTL}_{sn} - 60\right)
\end{equation}
If the calculated target gain ($G_{65}$) exceeds this dynamic limit, the excess gain ($Excess$) is quantified:
\begin{equation}
Excess = \max\left(0, G_{65} - L_{gain}\right)
\end{equation}
This excess gain is then softly compressed at a 2:1 ratio. The algorithm computes a sloping factor ($S_{factor}$) based on the difference between the specific frequency threshold and the best low-frequency threshold ($\text{HTL}_{bestlow}$), and applies a high-frequency weight ($W_{hf}$) fading in linearly from 2000 Hz to 4000 Hz:
\begin{equation}
S_{factor} = \max\left(0, \min\left(1, \frac{\text{HTL}_{sn} - \text{HTL}_{bestlow} - 25}{20}\right)\right)
\end{equation}
\begin{equation}
W_{hf} = \max\left(0, \min\left(1, \frac{f - 2000}{2000}\right)\right)
\end{equation}
\begin{equation}
G_{65} = G_{65} - (W_{hf} \cdot S_{factor} \cdot (Excess \cdot 0.50))
\end{equation}

### H. Dynamic Range Mapping (LDL Squeeze)

Following the foundational philosophy of the DSL v5.0 prescriptive method (Scollie et al., 2005), Open-NL integrates explicit dynamic range mapping to accommodate reduced Uncomfortable Loudness Levels. It is important to note that the algorithm utilizes two distinct discomfort predictors for different theoretical purposes: an HL-domain LDL predictor for estimating clinical audiometric dynamic range (Section II.H), and an SPL-domain UCL predictor for establishing physical device saturation limits (Section II.J).

When a patient exhibits a lower-than-expected clinical LDL, blindly applying unmodified target gain results in discomfort. To prevent this, the algorithm calculates a predicted HL-domain LDL based on threshold and conductive loss:
\begin{equation}
\text{LDL}_{predicted} = 100 + \max(0, \text{HTL}_{sn} - 40) \cdot 0.5 + \text{Loss}_{conductive}
\end{equation}
The algorithm then quantifies the dynamic range "squeeze" by comparing the measured LDL to the predicted LDL. For every 1 dB the patient's dynamic range is reduced, target insertion gain ($G_{65}$) is proportionally attenuated by 0.2 dB to ensure the speech envelope fits within the restricted auditory space.

### I. Transducer Bandwidth Roll-off

Consistent with the empirical evidence underpinning modern prescriptive targets like NAL-NL2 (Keidser et al., 2011), it is well established that acoustic transducers physically struggle to accurately reproduce frequencies at the extreme margins of the audiometric spectrum (e.g., $\le$ 250 Hz and $\ge$ 6000 Hz). Attempting to apply massive insertion gain targets in these regions inevitably leads to mechanical distortion, phase irregularities, and severe acoustic feedback, often with negligible or negative contributions to the Speech Intelligibility Index. 

To mitigate these physical limitations, Open-NL applies a continuous fractional bandwidth roll-off multiplier to the target gain array. For adult populations, this multiplier dictates a target scaling of 0.7$\times$ at 250 Hz, 1.0$\times$ through the mid-frequencies, 0.8$\times$ at 6000 Hz, and 0.5$\times$ at 8000 Hz. For pediatric populations, where higher frequencies are critical for language acquisition, the high-frequency roll-off is entirely disabled, maintaining a 1.0$\times$ multiplier through 8000 Hz.

### J. Dynamic WDRC computation (compression ratios)

Following the derivation of the 65 dB SPL anchor, Open-NL calculates discrete targets for soft (50 dB SPL) and loud (80 dB SPL) inputs. Base compression ratios ($\text{CR}_{base}$) are dynamically derived per-frequency band by comparing the distance between the threshold and the Maximum Power Output (MPO) limit (where the predicted Uncomfortable Loudness Level is derived natively from thresholds via $\text{UCL}_{spl} = 105 + 0.5 \cdot \max(0, \text{HTL}_{sn} - 20)$, based on the empirical National Acoustic Laboratories procedure for selecting saturation sound pressure levels established by Storey et al., 1998). Note that this SPL-domain formula deliberately differs from the HL-domain LDL predictor in Section II.H, as it specifically bounds the maximum acoustic output limit (MPO) of the device rather than estimating the clinical audiometric dynamic range. 

For moderate losses, the CR scales conservatively:
\begin{equation}
\text{CR}_{base} = 1 + \frac{\max\left(0, \text{HTL}_{sn} - 20\right)}{40}
\end{equation}

For severe losses (>65 dB HL), Open-NL operates on the theoretical design assumption that patients with extensive cochlear damage often have degraded temporal resolution and prefer lower compression (1:1 to 2:1) to preserve the temporal speech envelope. The compression ratio for loud inputs ($\text{CR}_{loud}$) is explicitly reduced back toward linear:
\begin{equation}
\text{CR}_{loud} = \max\left(1.0, \text{CR}_{base} - \left( \frac{\max\left(0, \text{HTL}_{sn} - 65\right)}{30} \right) \cdot (1.5 - 0.5 \cdot F_{mod})\right)
\end{equation}
where $F_{mod}$ is a frequency-dependent modulation factor that preserves higher compression ratios in the critical high-frequency speech bands:
\begin{equation}
F_{mod} = \max\left(0, \min\left(1, \frac{f - 500}{2500}\right)\right)
\end{equation}

### K. Conductive component correction

For mixed hearing losses, Open-NL restores 75% of the air-bone gap (ABG) as linear gain. This formally implements the 75% ABG + BC convention (Johnson, 2013), ensuring that the compression ratio tracks only the sensorineural component. It should be noted that whether listeners prefer exactly 75% restoration remains an unresolved empirical question. Because algorithmic outcomes for conductive profiles depend heavily on this specific restoration fraction, a targeted sensitivity analysis was conducted on the A7 profile (pure conductive 50 dB HL loss) across 25%, 50%, 75%, and 100% ABG restoration fractions. The results confirm a massive, monotonic reliance on this single parameter: at 25% restoration, the algorithm achieves an SII of 0.41 at 0.015 sones; at 50% restoration, it achieves an SII of 0.70 at 0.220 sones; and at the default 75% restoration, it effectively maxes out the 30 dB safety cap, achieving an SII of 0.93 at 0.4 sones. (Because the safety cap engages, 100% restoration yields identical results to the 75% baseline). This confirms the expected mathematical behavior of the algorithm but strictly isolates the dramatic A7 intelligibility jump seen in Table IV as an artifact of this unvalidated 75% constant. To prevent upward spread of masking, an original Open-NL 6 dB low-frequency taper is uniquely applied to this ABG gain, smoothly fading out by 1000 Hz.

### L. Comfort in noise (CIN) module

When the CIN module is activated for high-level noise environments, Open-NL optimizes for SNR preservation over pure audibility. Drawing inspiration from modern Comfort in Noise heuristics (Kitterick et al., 2026), Open-NL acknowledges that compression preference is highly heterogeneous and interacts with the degree of loss and concurrent noise reduction. Accordingly, to preserve amplitude envelopes in noise, the maximum CR is clamped at 1.5:1 (near-linear), and the compression threshold (CT) is reduced by 10 dB, shifting the compressive knee-point to a lower input level while simultaneously applying a shallower, more linear compression slope.

### M. Acoustic venting and signal purity

Acoustic coupling heavily influences the Real-Ear Aided Response (REAR). When modeling open or vented fittings, Open-NL integrates the expected low-frequency leakage ($V_{loss}$) into the target derivation. Crucially, the algorithm permits insertion gain targets to drop into negative values to match this physical leakage. This prevents the hearing aid from attempting to generate excessive internal gain to overcome the vent—a situation that leads to comb filtering and physical acoustic feedback. 

### N. Pediatric RECD scaling

To prevent the dangerous over-amplification of small ear canals, Open-NL parses exact chronological age (e.g., `child_6_11` for 6-11 months) and applies explicitly coded Real-Ear-to-Coupler Difference (RECD) acoustic scaling values, dynamically reducing the final Insertion Gain and Maximum Power Output (MPO) limits.

![Experience and RECD sensitivity. Note that the child curve prescribes approximately 5 dB more overall gain (including in the low frequencies) for this moderate loss, while additionally disabling the high-frequency roll-off.](/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/Figure4_Sensitivity.png){width=100%}

### O. Consolidated Uncalibrated Constants

Because Open-NL functions strictly as a modifiable computational testbed rather than a clinically validated prescriptive formula, several structural parameters remain mathematically uncalibrated. Table II provides a consolidated summary of these asserted heuristics, explicitly outlining their design justification and unvalidated status.

**TABLE II. Summary of Uncalibrated Heuristic Constants.**

| Parameter | Value | Description | Justification | Validation Status |
| :--- | :--- | :--- | :--- | :--- |
| Base Gain Anchor | 0.46 | Half-gain multiplier ($G_{base}$) | Balances Lybarger half-gain rule with preferred gain evidence (Leijon 1991). | Asserted Heuristic / Uncalibrated |
| Severe-Loss Booster Slope | 0.15 | Applied linearly to thresholds 60–80 dB HL | Gently assists profound losses without triggering explosive recruitment. | Hypothesis-generating heuristic |
| High-Frequency Gain Cap Base | 30 dB | Base limit for $L_{gain}$ soft-compression | Manages upward spread of masking and distortion in severe impairments. | Asserted mathematical choice |
| High-Frequency Gain Cap Slope | 0.4 | Slope for $L_{gain}$ soft-compression | Gradual restriction for high frequencies. | Asserted mathematical choice |
| Dynamic Range Squeeze | 0.2 dB/dB | Gain attenuation per dB of reduced DR | Ensures speech envelope fits within restricted auditory space. | Asserted mathematical choice |
| Reverse-Slope Floor | -10 dB | Gain floor for negative slopes | Cautiously prevents masking of intact basal units. | Asserted Heuristic / Uncalibrated |
| ABG Restoration | 75% | Mixed loss linear gain restoration | Formalizes common 75% ABG + BC clinical convention (Johnson 2013). | Unvalidated single-point constant |

## III. EVALUATION AND TRADE-OFF ANALYSIS

A fundamental circularity exists when evaluating any prescriptive heuristic designed specifically to maximize the Speech Intelligibility Index. Because Open-NL's gain shaping is tuned specifically to maximize the mathematical ANSI SII metric, utilizing the `sii()` engine to benchmark its targets against other validated prescriptions (like NAL-NL2) within a simulated environment yields a tautological advantage. To properly evaluate algorithmic efficiency, theoretical intelligibility must be charted against an independent constraint: overall loudness. A theoretical target that achieves comparable or higher SII at a comparable or lower predicted loudness is traditionally framed as demonstrating algorithmic efficiency, though this purely mathematical efficiency assumes the predicted audibility translates to real-world benefit and must be evaluated against the optimizer's ~1.50 sones combined uncertainty budget.

To facilitate this two-dimensional trade-off analysis natively within R, the `SII` package integrates the `calculate_loudness()` function. Rather than relying on external MATLAB runtimes, this module implements a native, highly optimized C++ port of the canonical Moore & Glasberg (2004) specific-loudness model, directly mirroring the exact logic of its implementation in the Auditory Modeling Toolbox (AMT; Majdak et al., 2022) via the `bramslow2004` function. By executing the exact time-domain equivalent mathematical integrations—including the compressive specific loudness formula $N' = C_{imp} \times [(E + A)^\alpha - A^\alpha]$ and dynamic outer hair cell (OHC) filter widening—in a compiled C++ environment, the engine achieves close structural correspondence with the canonical model. Furthermore, to accommodate conductive and mixed hearing losses, the engine accurately attenuates the input signal by the air-bone gap prior to cochlear excitation. 

To achieve the sub-second execution speeds required for the Nelder-Mead iterative optimization loop across thousands of iterations, the internal `SII` engine interpolates the acoustic spectrum at a reduced 10 Hz resolution rather than a fine 0.5 Hz integration. While this reduction in spectral resolution significantly accelerates the calculation, it introduces a systemic numerical integration error in the final loudness approximation. It is important to note that this native C++ engine is designed strictly as an internal mathematical optimization heuristic, and individualized loudness perception requires variables beyond simple cochlear gain loss. To ensure scientific rigor, all final loudness values reported in Table IV were computed independently using the canonical Moore & Glasberg (2004) reference framework via the AMT `bramslow2004` implementation in MATLAB/Octave. Table III provides a side-by-side comparison of the internal 10 Hz optimization engine against the canonical reference to quantify this resolution-based estimation error. Given the extreme structural alignment of the C++ port, the remaining variance is almost entirely attributable to the Riemann sum step size (10 Hz vs FFT bin integration) and the steady-state frequency-domain approximation of Schroeder-phase time-domain signals. To ensure this minor variance does not contaminate the reported modeled metrics, all final loudness values evaluated in Table IV and Table V are completely independent of the internal C++ engine and contain no such compounding error. Using this embedded engine, Open-NL was benchmarked against exact insertion gain targets generated directly from the proprietary NAL-NL2 version 2 software (National Acoustic Laboratories, Sydney, Australia) for a 65 dB SPL input. These targets were evaluated across a seven-profile evaluation framework adapted from Johnson and Dillon (2011), which utilizes five standard sensorineural audiograms originally defined by Byrne et al. (2001) alongside one mixed (A6) and one conductive (A7) case.

**TABLE III. Validation of the 10 Hz C++ Optimizer Engine against the Canonical Moore & Glasberg (2004) Model (Monaural Sones).**

| Profile | Formula | 10 Hz Engine (Sones) | Moore & Glasberg (Sones) | Difference |
| :--- | :--- | :--- | :--- | :--- |
| A1 | NAL-NL2 | 12.66 | 12.19 | +0.47 |
| A1 | Open-NL | 7.72 | 7.66 | +0.06 |
| A2 | NAL-NL2 | 3.91 | 3.71 | +0.20 |
| A2 | Open-NL | 6.72 | 6.87 | -0.15 |
| A3 | NAL-NL2 | 8.86 | 8.47 | +0.39 |
| A3 | Open-NL | 7.78 | 7.53 | +0.25 |
| A4 | NAL-NL2 | 6.92 | 6.10 | +0.82 |
| A4 | Open-NL | 8.64 | 7.98 | +0.66 |
| A5 | NAL-NL2 | 7.58 | 7.55 | +0.03 |
| A5 | Open-NL | 7.31 | 7.07 | +0.24 |
| A6 | NAL-NL2 | 4.32 | 4.19 | +0.13 |
| A6 | Open-NL | 1.57 | 3.64 | -2.07 |
| A7 | NAL-NL2 | 0.36 | 0.36 | 0.00 |
| A7 | Open-NL | 1.01 | 1.72 | -0.71 |
| **MEAN** | **Overall** | **5.38** | **5.36** | **0.44 MAE** |


**TABLE IV. Canonical Monaural Loudness (Sones) and Theoretical SII across A1-A7 Audiograms (65 dB SPL Input).**

| Profile | Formula | Loudness (Sones) | SII (0-1) |
|---|---|---|---|
| A1 | NAL-NL2 | 12.19 | 0.80 |
| A1 | Open-NL | 7.66 | 0.86 |
| A2 | NAL-NL2 | 3.71 | 0.88 |
| A2 | Open-NL | 6.87 | 0.86 |
| A3 | NAL-NL2 | 8.47 | 0.73 |
| A3 | Open-NL | 7.53 | 0.83 |
| A4 | NAL-NL2 | 6.10 | 0.80 |
| A4 | Open-NL | 7.98 | 0.85 |
| A5 | NAL-NL2 | 7.55 | 0.67 |
| A5 | Open-NL | 7.07 | 0.79 |
| A6 | NAL-NL2 | 4.19 | 0.87 |
| A6 | Open-NL | 3.64 | 0.88 |
| A7* | NAL-NL2 | 0.36 | 0.69 |
| A7* | Open-NL | 1.72 | 0.93 |

*\*A7 results are a mathematical artifact of the unvalidated 75% ABG restoration constant (see Section II.K).*

It is necessary to acknowledge a methodological limitation inherent to this dual-engine approach. Because the Nelder-Mead optimizer maximizes SII subject to the internal 10 Hz resolution engine constraint, the 0.44 sone mean absolute error introduces a measurable convergence bias. Critically, this error is not uniform: the individual discrepancies for the A6 (-2.07 sones) and A7 (-0.71 sones) profiles are large relative to the ~1.50 sone overall uncertainty budget. Because the optimizer selects its final target based on this biased surface, this magnitude of individual-profile error undercuts even "heuristic neighborhood" claims for A6 and A7 specifically. The final evaluation in Table IV relies on the unbiased canonical Moore & Glasberg (2004) framework, meaning the Open-NL targets derived here do not represent the absolute theoretical optimum under a strict canonical integration. Future iterations utilizing natively compiled full-resolution integrations would be required to eliminate this disconnect and guarantee strict canonical Pareto optimality. While the final Open-NL targets for the primary sensorineural test profiles (A1–A5) were explicitly verified against the unbiased canonical loudness engine in Table IV—successfully mapping the mathematical boundaries of the intelligibility-loudness space for those pathologies—the outputs for the mixed and conductive profiles (A6 and A7) cannot support heuristic optimization claims due to the internal engine's profile-specific error.


It is critical to evaluate these results through the lens of the loudness frontier rather than raw SII maximization. Two boundary cases (A2 and A7) specifically illustrate the clinical hazards of unconstrained theoretical audibility and warrant careful interpretation. For the reverse-slope A2 profile, Open-NL outputs a heuristic target that drives canonical loudness to 6.87 sones (vs. NAL-NL2's 3.71 sones) while actually yielding a slightly *worse* theoretical SII (0.86 vs 0.88). Crucially, the optimizer selected this A2 target despite accurately modeling the severe loudness penalty internally (Table III). Therefore, this A2 boundary behavior is a genuine feature of the unconstrained theoretical loudness-intelligibility trade-off space, demonstrating that blindly maximizing mathematical audibility for reverse-slope configurations readily produces massive loudness costs for no meaningful intelligibility benefit. Similarly, the A7 conductive profile achieves an artificially high 0.93 SII purely as a mathematical artifact of the unvalidated 75% air-bone gap restoration constant rather than an optimized sensorineural tradeoff. These edge cases underscore that these targets are heuristic outputs—not canonical findings—and that raw theoretical SII maximization cannot supersede clinical judgment. The algorithm is designed for hypothesis generation and heuristic boundary exploration rather than direct clinical application.

*Note: Loudness values computed using the canonical Moore & Glasberg (2004) specific loudness model, validated within the Auditory Modeling Toolbox (AMT; Majdak et al., 2022) via the bramslow2004 implementation.*

Because Open-NL directly maximizes the Speech Intelligibility Index (SII) while using NAL-NL2 as a soft constraint (anchor penalty), comparing the resulting SII scores between the two formulas conveys little information about relative merit. Instead, as the literature demonstrates, prescription choice has a minimal effect on actual measured speech intelligibility but marked effects on predicted loudness (Johnson & Dillon, 2011; Ching et al., 2013). The analysis must therefore be reframed entirely around the loudness-constrained frontier, which is the only genuinely independent axis.

![Modeled Loudness Optimization for A1-A7 Profiles (*Note: A7 outcomes are an artifact of the unvalidated 75% ABG restoration constant*).](/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/Figure2_Optimization_Loudness.png)

For mild sloping losses (A1), Open-NL yields higher theoretical audibility (SII = 0.86) while generating significantly lower overall loudness (7.66 sones) compared to NAL-NL2 (SII = 0.80, 12.19 sones). This occurs because Open-NL assigns 0.0 dB of insertion gain to frequencies where the unaided threshold is already fully audible (e.g., 250 Hz, where A1 has a 10 dB HL threshold). While NAL-NL2 prescribes gain in these regions—likely for timbre matching or vent compensation—Open-NL restricts it. However, this result must be treated purely as illustrative optimizer behavior rather than a clinical finding. Assuming it represents a true efficiency gain ignores the circularity of scoring the algorithm with its own maximization metric. Furthermore, extensive evidence demonstrates that for many hearing-impaired listeners, particularly at high frequencies, increased audibility does not proportionally increase intelligibility due to suprathreshold distortion (Ching, Dillon, & Byrne, 1998; Margolis et al., 2025).

![Insertion Gain Targets for 65 dB SPL Input across standard audiometric profiles.](/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/Figure3_Insertion_Gain.png){width=100%}

Conversely, in severe sloping losses (A5), Open-NL provides another example of illustrative optimizer behavior regarding spectral reallocation. For the A5 profile, Open-NL achieves higher mathematical intelligibility (SII = 0.79 vs 0.67) at a predicted loudness (7.07 sones vs 7.55 sones) that is lower than the baseline. The optimizer reaches this state by actively suppressing gain in the extreme frequencies to reallocate acoustic energy to the speech-critical mid-frequencies. However, it is critical to note that the standard ANSI SII framework omits the suprathreshold distortion component. As established in the literature, the gap between mathematically predicted and clinically measured word recognition systematically widens with increasing hearing loss and steep configurations like A3–A5 (Johnson & Dillon, 2011; Bernstein et al., 2013; Hülsmeier et al., 2022). Ching, Dillon, and Byrne (1998) demonstrated that audibility alone cannot explain recognition, and that severe or profound high-frequency regions may actually warrant low or zero sensation-level targets—directly contradicting the output of an unconstrained SII-maximizer. Therefore, the higher raw SII achieved by Open-NL in these severely impaired ears must be explicitly flagged as an over-prediction artifact of the ANSI model rather than a modeled clinical benefit. 

In other profiles, Open-NL explicitly abandons the goal of efficiency in favor of pure audibility maximization. For example, in the conductive A7 profile, Open-NL reaches 1.72 sones to achieve extremely high intelligibility (SII = 0.93), compared to NAL-NL2's 0.36 sones at an SII of 0.69. This is not an efficiency gain; it is simply more gain buying more audibility, which any linear formula can achieve. This result is almost entirely an artifact of Open-NL's 75% ABG linear-restoration choice (Section II.K), highlighting why such unvalidated single-point parameters require rigorous behavioral sensitivity testing. Similarly, under the inclusion of reverse-slope compensation physics, the heuristic output for the mild reverse-slope loss (A2) actually degrades intelligibility slightly (SII = 0.86 vs NAL-NL2's 0.88) at the cost of significantly higher predicted loudness (6.87 sones vs 3.71 sones). This represents a massive loudness cost for no meaningful intelligibility benefit, underscoring that an unconstrained mathematical framework can readily produce clinically undesirable targets when aggressively pursuing audibility in reverse-slope pathologies. In these specific instances, Open-NL functions as a theoretical demonstration of the extreme heuristic boundaries of the intelligibility-loudness framework, rather than true optimized trade-off findings.

It must be explicitly acknowledged that the evaluation scope presented herein—testing seven hypothetical audiograms by a single author without human subjects—is strictly demonstrative. This narrow evaluation cannot support any generalizable claim regarding clinical superiority or patient preference. Open-NL is exclusively an open-source computational testbed for researchers to modify and model isolated prescriptive rules. Any extrapolation of these derived targets to human patients requires independent institutional review, comprehensive real-ear verification, and rigorous behavioral validation.

Crucially, as established by the comparative data of Johnson and Dillon (2011, 2013) and Ching, Dillon, and Byrne (1998), maximizing the raw physical-audibility ANSI SII metric does not straightforwardly equate to maximized clinical benefit. The literature consistently demonstrates that prescription choice has a minimal effect on actual measured speech intelligibility but marked effects on predicted loudness. Furthermore, "effective audibility" research indicates that adding high-frequency gain becomes progressively less useful as sensorineural loss increases, with severe high-frequency losses often requiring lower or zero sensation level targets rather than aggressive linear compensation (Ching, Dillon, & Byrne, 1998). Because Open-NL structurally optimizes for the raw SII metric, its highest-scoring targets may over-predict the usefulness of amplified regions in severely impaired ears. This limitation is well documented in distortion-categorization frameworks (Margolis et al., 2025). High amounts of prescribed gain may increase physical audibility but severely degrade true perceptual clarity.

Furthermore, it must be explicitly noted that any translation from raw SII to predicted intelligibility depends entirely on the chosen transfer function, which is inherently listener-, age-, and hearing-level-specific. As established by Scollie (2008), adult-derived transfer functions systematically over-predict children's speech recognition scores. Consequently, the adult-derived CID W-22 transfer function utilized in this paper's appendix—along with any raw SII interpretation throughout the broader Open-NL evaluation—is not safely portable to the pediatric use cases (e.g., DSL v5.0 targets, age-specific RECDs) supported elsewhere in the package architecture. The framework serves as a theoretical baseline exposing these algorithmic mechanics, rather than a clinical directive asserting that higher raw SII unconditionally improves patient outcomes.

## IV. SOFTWARE ARCHITECTURE AND THE INTERACTIVE DASHBOARD

A major objective of the `SII` package is translating complex acoustical mathematics into a usable format for both clinical researchers and audiological educators. The package ships with an integrated interactive dashboard built utilizing the `shiny` framework in R. 

Rather than relying on web-based emulators or external servers, the dashboard is distributed natively within the CRAN package itself. By executing the `launch_app()` function, researchers can spin up a local instance of the application directly on their own machine. This native R execution ensures absolute numerical stability—avoiding the floating-point emulation inconsistencies inherent to WebAssembly (Wasm)—and guarantees that sensitive patient audiometric data never leaves the local computer. Furthermore, to reinforce its scope as a research framework rather than regulated diagnostic software, the application is explicitly flagged within its interface as a non-clinical academic tool, prohibiting its unapproved use for direct patient care.

The application provides a graphical user interface (GUI) where researchers can input standard audiograms, bone conduction thresholds, and LDLs. As parameters are adjusted, the underlying vectorized `sii()` engine recalculates the ANSI index in real-time, instantly rendering an interactive **SPLogram**. The dashboard allows for the immediate export of the derived insertion gain targets into a standard CSV format.

### A. Code examples

The `SII` package utilizes a highly accessible, object-oriented API in R, facilitating the generation of reproducible figures for clinical publications via the command line.

**Listing 1: Generating WDRC Targets**
```R
library(SII)

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
thresholds <- c(20, 25, 40, 60, 75, 80)

# Calculate Open-NL for Average (65 dB)
sii_65 <- sii(speech = 65, threshold = thresholds, 
              freq = freqs, prescription = "Open-NL")

# Extract the calculated insertion gain targets
sii_65$gain
```

## V. CONCLUSION

Open-NL provides a transparent, customizable computational framework for predicting WDRC insertion gain targets and benchmarking them against established industry standards natively within R. By coupling an explicitly defined mathematical pipeline with an embedded hybrid loudness model, the `SII` package allows audiologists and researchers to freely simulate and evaluate the theoretical intelligibility-loudness trade-off of various prescriptive heuristics without relying on opaque clinical fitting software. It is critically important to emphasize that Open-NL is currently a computational toolkit designed exclusively for theoretical modeling and simulation. It has not undergone clinical validation and is strictly contraindicated for general clinical fitting. Given the inclusion of exploratory features like the severe-loss booster and dynamic MPO attenuation, applying these raw targets to human subjects carries an inherent risk of over-amplification or discomfort. Any future application of Open-NL targets to human subjects must occur exclusively within the strictly controlled context of Institutional Review Board (IRB) approved research studies, and mandates independent real-ear verification and rigorous loudness-discomfort safety checks.

## ACKNOWLEDGMENTS

The author wishes to thank the original developers of the R-project ecosystem and the countless open-source contributors whose foundational work enabled the creation of this computational toolkit.

## AUTHOR DECLARATIONS

### Conflict of Interest

The author declares no conflicts of interest.

### Ethics Approval

The author declares that no animal subjects or human participants were involved in the development, theoretical simulation, or mathematical validation presented in this research. Because Open-NL is distributed strictly as a theoretical computational toolkit, any future application of the algorithm to human participants by independent investigators requires separate Institutional Review Board (IRB) approval, informed consent, and rigorous audiological safety protocols. Furthermore, no identifiable data are embedded in the interactive Shiny application or the code repository.

## DATA AVAILABILITY

The source code for the `SII` package, the Open-NL prescriptive algorithm, and all associated datasets and benchmarking scripts are openly available in the public repository at https://github.com/r-gregmisc/SII (v1.1.8; DOI: [DOI to be generated upon final repository release]; License: GPL-3.0).

## REFERENCES

\begingroup
\setlength{\parindent}{-0.5in}
\setlength{\leftskip}{0.5in}

Berger, K. W., Hagberg, E. N., & Rane, R. L. (1980). "A Reexamination of the One-Half Gain Rule," Ear and Hearing.

Bramsløw, L. (2004). "An objective estimate of the perceived quality of reproduced sound in normal and impaired hearing," Acta Acustica united with Acustica.

Byrne, D., Dillon, H., Ching, T., Katsch, R., & Keidser, G. (2001). "NAL-NL1 Procedure for Fitting Nonlinear Hearing Aids: Characteristics and Comparisons With Other Procedures," Journal of the American Academy of Audiology.

Byrne, D., & Dillon, H. (1986). "The National Acoustic Laboratories' (NAL) new procedure for selecting the gain and frequency response of a hearing aid," Ear and Hearing.

Byrne, D., et al. (1990). "An international comparison of long-term average speech spectra," The Journal of the Acoustical Society of America.

Byrne, D., Parkinson, A., & Newall, P. (1990). "Hearing Aid Gain and Frequency Response Requirements for the Severely/Profoundly Hearing Impaired," Ear and Hearing.

Bernstein, J. G., Summers, V., Grassi, E., & Grant, K. W. (2013). "Auditory models of suprathreshold distortion and speech intelligibility in persons with impaired hearing," Journal of the American Academy of Audiology.

Chen, Z., Hu, G., Glasberg, B. R., & Moore, B. C. J. (2011). "A new model for calculating auditory excitation patterns and loudness for cases of cochlear hearing loss," The Journal of the Acoustical Society of America.

Ching, T. Y., Dillon, H., & Byrne, D. (1998). "Speech Recognition of Hearing-Impaired Listeners: Predictions From Audibility and the Limited Role of High-Frequency Amplification," The Journal of the Acoustical Society of America.

Ching, T. Y., Johnson, E. E., Hou, S., et al. (2013). "A Comparison of NAL and DSL Prescriptive Methods for Paediatric Hearing-Aid Fitting: Predicted Speech Intelligibility and Loudness," International Journal of Audiology.

Convery, E., & Keidser, G. (2011). "Transitioning Hearing Aid Users With Severe and Profound Loss to a New Gain/Frequency Response: Benefit, Perception, and Acceptance," Journal of the American Academy of Audiology.

Denk, F., Oetting, D., Latzel, M., Bonsel, H., & Husstedt, H. (2025). "Prevalence of Excess Binaural Broadband Loudness Summation in the Hearing-Impaired Population and Implications for Hearing Aid Gain Targets," PloS One.

Engler, M., Digeser, F., & Hoppe, U. (2026). "Speech Recognition and Real-Ear-Measured Amplification in Hearing-Aid Users With Various Grades of Hearing Loss," International Journal of Audiology.

Halpin, C., Thornton, A., & Hasso, M. (1994). "Low-Frequency Sensorineural Loss: Clinical Evaluation and Implications for Hearing Aid Fitting," Ear and Hearing.

Hornsby, B. W., Johnson, E. E., & Picou, E. (2011). "Effects of Degree and Configuration of Hearing Loss on the Contribution of High- And Low-Frequency Speech Information to Bilateral Speech Understanding," Ear and Hearing.

Horwitz, A. R., Ahlstrom, J. B., & Dubno, J. R. (2008). "Factors Affecting the Benefits of High-Frequency Amplification," Journal of Speech, Language, and Hearing Research.

Hülsmeier, D., et al. (2022). "Inference of the distortion component of hearing impairment from speech recognition by predicting the effect of the attenuation component," International Journal of Audiology.

Johnson, E. E. (2013). "An Initial-Fit Comparison of Two Generic Hearing Aid Prescriptive Methods (NAL-NL2 and CAM2) to Individuals Having Mild to Moderately Severe High-Frequency Hearing Loss," Journal of the American Academy of Audiology.

Johnson, E. E., & Dillon, H. (2011). "A Comparison of Gain for Adults From Generic Hearing Aid Prescriptive Methods: Impacts on Predicted Loudness, Frequency Bandwidth, and Speech Intelligibility," Journal of the American Academy of Audiology.

Keidser, G., Dillon, H., Carter, L., & O'Brien, A. (2012). "NAL-NL2 Empirical Adjustments," Trends in Amplification.

Kaur, C., Wu, P. Z., O'Malley, J. T., & Liberman, M. C. (2023). "Predicting Atrophy of the Cochlear Stria Vascularis From the Shape of the Threshold Audiogram," The Journal of Neuroscience.

Kitterick, P. T., Zakis, J. A., & Edwards, B. (2026). "Evolving the Philosophy: From the NAL Rule to NAL-NL3," International Journal of Audiology.

Leijon, A. (1991). "Hearing Aid Gain for Loudness-Density Normalization in Cochlear Hearing Losses With Impaired Frequency Resolution," Ear and Hearing.

Leijon, A., Lindkvist, A., Ringdahl, A., & Israelsson, B. (1991). "Sound Quality and Speech Reception for Prescribed Hearing Aid Frequency Responses," Ear and Hearing.

Lybarger, S. F. (1944). U.S. Patent Application SN 543,278.

Majdak, P., Hollmach, V., & Søndergaard, P. L. (2022). "The Auditory Modeling Toolbox," in The Technology of Binaural Understanding.

Margolis, R. H., Hornsby, B. W. Y., Saly, G. L., & Wilson, R. H. (2025). "Predicted and Measured Word-Recognition Scores Unmask Distortion in the Impaired Auditory System," The Journal of the Acoustical Society of America.

Moore, B. C. J., & Glasberg, B. R. (2004). "A revised model of loudness perception applied to cochlear hearing loss," Hearing Research.

Moore, B. C. J., Gibbs, A., Onions, G., & Glasberg, B. R. (2014). "Measurement and Modeling of Binaural Loudness Summation for Hearing-Impaired Listeners," The Journal of the Acoustical Society of America.

Mueller, H. G. (2005). "Fitting Hearing Aids to Adults Using Prescriptive Methods: An Evidence-Based Review of Effectiveness," Journal of the American Academy of Audiology.

Pieper, I., Mauermann, M., Kollmeier, B., & Ewert, S. D. (2021). "Toward an Individual Binaural Loudness Model for Hearing Aid Fitting and Development," Frontiers in Psychology.

Pieper, I., Mauermann, M., Oetting, D., Kollmeier, B., & Ewert, S. D. (2018). "Physiologically Motivated Individual Loudness Model for Normal Hearing and Hearing Impaired Listeners," The Journal of the Acoustical Society of America.

Plomp, R. (1978). "Auditory handicap of hearing impairment and the limited benefit of hearing aids," The Journal of the Acoustical Society of America.

Plyler, P. N., & Fleck, E. L. (2006). "The Effects of High-Frequency Amplification on the Objective and Subjective Performance of Hearing Instrument Users With Varying Degrees of High-Frequency Hearing Loss," Journal of Speech, Language, and Hearing Research.

Scollie, S. (2008). "Children's Speech Recognition Scores: The Speech Intelligibility Index and Proficiency Factors for Age and Hearing Level," Ear and Hearing.

Storey, L., Dillon, H., Yeend, I., & Wigney, D. (1998). "The National Acoustic Laboratories' procedure for selecting the saturation sound pressure level of hearing aids: Experimental validation," Ear and Hearing.

Studebaker, G. A., & Sherbecoe, R. L. (1991). "Frequency-importance and transfer functions for recorded CID W-22 word lists," Journal Speech and Hearing Research.

Van Tasell, D. J., & Turner, C. W. (1984). "Speech Recognition in a Special Case of Low-Frequency Hearing Loss," The Journal of the Acoustical Society of America.

\par\endgroup

## APPENDIX: EXPLORATORY MODULES

### A. Distortion-aware high-frequency penalty (untested heuristic)

A fundamental limitation of existing prescriptive algorithms is their reliance on the pure-tone audiogram, which ignores suprathreshold processing deficits inherent to outer/inner hair cell loss and synaptopathy (Plomp, 1978). Open-NL includes an explicitly untested heuristic designed to theoretically integrate the distortion categorization framework recently proposed by Margolis et al. (2025). The engine calculates a predicted Word Recognition Score (WRS) using the established CID W-22 transfer function (where the base is 10, valid for $0.0 \le \text{SII} \le 1.0$) (Studebaker & Sherbecoe, 1991):
\begin{equation}
\text{Predicted WRS (\%)} = 100 \cdot (1 - 10^{-(\text{SII} \cdot 3.28)})
\end{equation}
Per the Margolis et al. (2025) framework, the degree of cochlear distortion is categorized based on population distributions of measured-minus-predicted WRS differences, rather than a single-point comparison. Open-NL then dynamically alters the prescription targets for highly distorted ears by applying high-frequency roll-offs (e.g., $-10$ dB/octave starting at 1500 Hz) and lowering the $L_{gain}$ soft-compression limit to prevent high-frequency saturation. This feature is intended solely as an exploratory research tool to bridge pure-tone algorithms with suprathreshold diagnostic data, and its perceptual effects require extensive behavioral validation.
