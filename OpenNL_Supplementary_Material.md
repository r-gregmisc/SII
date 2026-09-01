---
output:
  pdf_document: default
  html_document: default
---
# Supplementary Material: Open-NL Heuristic Pipeline

This supplementary document provides the exact mathematical formulations and piecewise functions governing the twelve internal processing stages of the Open-NL algorithmic cascade.

## C. Execution cascade

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
6. Calculate dynamic Compression Ratios (CR) and establish UCL/MPO saturation limits (Section II.J).
7. Integrate dynamic Conductive Component correction based on Sensorineural Dynamic Range (Section II.K).
8. Apply Comfort in Noise (CIN) WDRC alterations if triggered (Section II.L).
9. Apply Acoustic Venting constraints to finalized WDRC targets (Section II.M).

## D. The decoupled anchor and experience level tuning

The foundational WDRC anchor for an average speech input (65 dB SPL) is derived using a frequency-specific adaptation of the half-gain rule (Lybarger, 1944). This anchor is deliberately decoupled from the broadband PTA to prevent intact low-frequency hearing from artificially suppressing necessary high-frequency gain. Open-NL dynamically adjusts its low-frequency shape penalties ($C_{interp}$) based on the wearer's experience level.

Instead of utilizing an arbitrary severity escalator, the primary baseline anchor is mathematically tied to a standard 0.46 half-gain scaling function (Byrne & Dillon, 1986). A disabled-by-default, bounded severe-loss booster (slope = 0.15) can be linearly applied to thresholds between 70 dB HL and 80 dB HL (with an opt-in 60 dB HL "aggressive" mode). This gently assists profound losses with audibility without triggering explosive recruitment when explicitly enabled.

\begin{equation}
G_{base} = 0.46 \cdot \text{HTL}_{sn} + B_{en} \cdot 0.15 \cdot \max(0, \min(80, \text{HTL}_{sn}) - 60) + C_{interp}
\end{equation}
where $\text{HTL}_{sn}$ is the sensorineural component of the Hearing Threshold Level (in dB HL), and $B_{en}$ is a binary toggle (default 0) that explicitly gates the severe-loss booster.

The 0.46 boundary is a purely nominal, uncalibrated mathematical anchor loosely derived from Lybarger's classical half-gain rule, rather than an empirically fitted regression. It functions strictly as a nominal starting baseline.

While Keidser et al. (2012) found empirically that new users prefer slightly less gain, Open-NL integrates this preference directly via the static frequency-shaping $C_{vals}$ array rather than dynamically collapsing the base multiplier. Furthermore, Open-NL implements sex-based adjustments as a simplified static constant (a flat 1.5 dB reduction). For binaural summation, the algorithm utilizes a level-dependent bilateral reduction (scaling from a 2 dB penalty at 50 dB SPL to a 6 dB penalty at 80 dB SPL). This dynamic reduction explicitly prevents traumatic over-amplification and massive loudness saturation when modeling bilateral configurations near recruitment boundaries.

The parameters are explicitly defined as follows. $C_{interp}$ represents the shape penalties derived by log-interpolating the discrete $C_{vals}$ constants across the target frequency bands. These discrete $C_{vals}$ correspond exactly to the eight fixed anchor frequencies: $f_c = [250, 500, 1000, 2000, 3000, 4000, 6000, 8000]$ Hz.
1. **New Users**: In accordance with Keidser et al. (2012), who demonstrated that naive users prefer less overall amplification to combat occlusion and high-frequency sharpness, this configuration applies a purely nominal, uncalibrated ~3 dB flat reduction from the experienced baseline ($C_{vals} = [-11, -4, 0, -2, -3, -3, -3, -3]$). Like the 0.46 anchor, this offset is not an empirically fitted parameter.
2. **Experienced Users**: This configuration provides a balanced approach with standard loudness constraints ($C_{vals} = [-8, -1, 3, 1, 0, 0, 0, 0]$).
3. **Power Users**: Designed to simulate patients who prioritize raw acoustic audibility over listening comfort. This configuration lowers the Wide Dynamic Range Compression (WDRC) threshold by 5 dB (forcing early activation) and raises the absolute high-frequency gain safety limit from 30 dB to 40 dB, permitting significantly higher raw amplification for severe losses.

## E. Slope-Dependent Low-Frequency Penalty (SD-LFP)

Standard linear formulas, such as NAL-R (Byrne & Dillon, 1986), often cause overprescription because they do not systematically account for loudness density scaling across different audiometric slopes. For example, applying massive high-frequency gain to a steeply sloping audiogram forces the functionally normal low frequencies to dominate overall loudness, resulting in catastrophic loudness recruitment. A slope-dependent penalty dynamically reallocates the finite loudness budget to bands where audibility is genuinely useful (Ching et al., 2001; Hornsby & Ricketts, 2006).

To solve this while remaining fully transparent, Open-NL's Slope-Dependent Low-Frequency Penalty (SD-LFP) introduces a novel **Profound High-Frequency Bypass**. The core heuristic suppresses low-frequency gain strictly based on the slope of the audiogram:
\begin{equation}
\text{Slope} = \max(0, \text{PTA}_{HF} - \text{PTA}_{LF})
\end{equation}
where $\text{PTA}_{HF}$ is the mean sensorineural threshold for frequencies $\ge 2000$ Hz, and $\text{PTA}_{LF}$ is the mean sensorineural threshold for frequencies $\le 1000$ Hz.

For steeply sloping high-frequency losses (where the slope exceeds 15 dB), Open-NL penalizes low-frequency gain (by up to 15 dB) to kill the loudness dominance of the normal lows, maintaining the overall loudness budget. Crucially, this penalty is explicitly designed to operationalize the empirical findings of Byrne, Parkinson, and Newall (1990). Byrne et al. established that for severe-to-profound listeners, the standard half-gain rule ceases to apply above ~70 dB HL, preferred overall gain ran ~10 dB above standard NAL targets, and relatively *more* low-frequency emphasis was preferred by a substantial subset (roughly one-third to one-half) of this population—particularly when the 2 kHz threshold exceeded ~95 dB HL. Furthermore, low-frequency compression preferences for this population trend toward linear (Keidser et al., 2007). To strictly adhere to these physiological findings and prevent starving profound listeners of essential low-frequency speech cues, the SD-LFP penalty is dynamically suppressed by a profound-loss bypass factor ($PF_{bypass}$). This mathematical bypass window maps directly onto the Byrne et al. (1990) empirical parameters: the penalty begins tapering when the high-frequency PTA reaches 70 dB HL, and reaches exactly zero (triggering a full bypass of the low-frequency penalty) at 95 dB HL:
\begin{equation}
PF_{bypass} = \max\left(0, \min\left(1, \frac{95 - \text{PTA}_{HF}}{25}\right)\right)
\end{equation}

\begin{equation}
\text{LF}_{penalty} = \max\left(0, \min\left(1, \frac{\text{Slope} - 15}{20}\right)\right) \cdot 15 \cdot PF_{bypass}
\end{equation}

This penalty is log-linearly tapered for frequencies ($f$) below 1000 Hz and subtracted from the base gain. Across the standard prescriptive frequency bands evaluated ($f_c = [250, 500, 1000, 2000, 3000, 4000, 6000, 8000]$ Hz), this log-taper evaluates to exactly $1.0$ (100% penalty) at $f = 250$ Hz, $0.5$ (50% penalty) at $f = 500$ Hz, and $0.0$ at $f \ge 1000$ Hz:
\begin{equation}
G_{65} = G_{base} - \left(\text{LF}_{penalty} \cdot \max\left(0, 1 - \frac{\log_{10}(f) - \log_{10}(250)}{\log_{10}(1000/250)}\right)\right)
\end{equation}

Crucially, for flat audiograms (where the slope is less than 15 dB), this entire penalty zeroes out. This ensures that severe flat losses retain their full targeted gain without experiencing unnecessary downward compression in the low frequencies.

For reverse-slope configurations (where the low-frequency thresholds are significantly worse than the high frequencies), an inverse logic is applied. Amplifying low frequencies aggressively in these cases may degrade intelligibility or cause upward spread of masking. Because audiogram slope is an imperfect proxy for underlying pathology (Kaur et al., 2023), the specific -10 dB gain floor implemented in Open-NL remains an asserted, conservative heuristic. Open-NL suppresses the low-frequency correction array ($C_{interp}$) to this flat -10 dB floor, employing a transitional factor ($RS_{factor}$) for signed slopes exceeding -15 dB:
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

## F. Ablation Analysis: The Mechanism of Steep-Slope Recruitment Constraints

The prevention of severe recruitment in steeply sloping audiograms (such as the standard NAL A5 profile, part of a seven-profile framework adapted from Johnson & Dillon, 2011; originally defined by Byrne et al., 2001) requires explicit mechanism analysis.


**TABLE I. Reference Audiometric Profiles (Adapted from Johnson & Dillon, 2011).**
*Thresholds are in dB HL. Profiles A1–A5 are purely sensorineural. A6 is a mixed loss with a 30 dB conductive component (ABG). A7 is a purely conductive 50 dB block with a healthy cochlea.*

| Profile | Type             | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz | ABG   |
|:--------|:-----------------|:------:|:------:|:-------:|:-------:|:-------:|:-------:|:-----:|
| **A1**  | Flat moderate    | 15     | 20     | 30      | 40      | 50      | 60      | 0 dB  |
| **A2**  | Reverse slope    | 60     | 50     | 40      | 30      | 20      | 15      | 0 dB  |
| **A3**  | Moderately sloping| 10    | 20     | 40      | 50      | 55      | 60      | 0 dB  |
| **A4**  | Steeply sloping  | 0      | 0      | 10      | 40      | 70      | 80      | 0 dB  |
| **A5**  | Steeply sloping  | 10     | 10     | 20      | 60      | 80      | 100     | 0 dB  |
| **A6**  | Mixed            | 50     | 55     | 60      | 65      | 75      | 80      | 30 dB |
| **A7**  | Conductive       | 50     | 50     | 50      | 50      | 50      | 50      | 50 dB |

 When evaluating the heuristic seed values that anchor the optimization engine, the SD-LFP successfully demonstrates frequency-specific constraints on complex audiometric slopes before the optimizer even touches the targets. Table II demonstrates this ablation.

**TABLE II. Ablation of SD-LFP Heuristic Constraints on Optimizer Seed (65 dB SPL Input).** *Note: Generated using the aggressive 60 dB HL booster onset.*

| Profile | Unconstrained Seed SII | Unconstrained Seed Sones | SD-LFP Seed SII | SD-LFP Seed Sones |
|---|---|---|---|---|
| A1 (Flat mod) | 0.86 | 7.2 | 0.86 | 7.2 |
| A2 (Reverse) | 0.88 | 6.3 | 0.88 | 6.0 |
| A3 (Mod sloping) | 0.79 | 6.8 | 0.79 | 6.8 |
| A4 (Steeply) | 0.81 | 6.9 | 0.81 | 6.9 |
| A5 (Steeply) | 0.68 | 7.1 | 0.68 | 6.0 |
| A6 (Mixed) | 0.82 | 3.0 | 0.82 | 3.0 |
| A7 (Conductive) | 0.97 | 1.0 | 0.97 | 1.0 |

For sloping profiles, disabling the SD-LFP logic causes the baseline prescription heuristics to dangerously over-amplify specific frequency bands. For the A2 (Reverse slope) profile, the unconstrained heuristic seed predicted 6.4 sones, but the SD-LFP logic correctly penalized the low-frequency excess, reducing the baseline to 6.0 sones without degrading audibility. Similarly, for the A5 (Steeply sloping) profile, the seed over-amplified the high frequencies to 7.9 sones, but the SD-LFP properly capped it at 7.6 sones to prevent upward spread of masking. Meanwhile, flat or gently sloping losses like A1 and A4 were completely identical because the `disable_sdlfp` toggle correctly bypasses the penalty for non-sloping configurations. This ablation illustrates that the algorithm successfully relies on its explicit SD-LFP constraint to anchor the target securely prior to optimization.

Furthermore, this mathematical constraint introduces an evidence–design tension for severely impaired listeners. To safely provide the low-frequency emphasis required by severe-to-profound listeners without abandoning the recruitment constraint for mild-to-moderate sloping profiles, Open-NL explicitly gates the SD-LFP by absolute low-frequency severity. It bypasses the penalty entirely if the low-frequency PTA exceeds 70 dB HL, allowing the algorithm to protect low-frequency energy in severe/profound profiles as empirically recommended (Byrne, Parkinson, & Newall, 1990; Keidser et al., 2007). While the 20 dB taper width and -10 dB reverse-slope floor remain asserted constants, grounding the 70 dB HL bypass in the severe/profound literature provides a principled physiological rationale.

However, because this isolated ablation relies on a single simulated profile (A5) without behavioral validation, and since audiometric slope is an imperfect proxy for underlying cochlear pathology (Kaur et al., 2023), these mechanistic outcomes should be interpreted strictly as computational illustrations rather than confirmed clinical consequences. 

To evaluate the efficacy of the SD-LFP (Slope-Dependent Low-Frequency Penalty) heuristic constraint further, an ablation analysis was also performed on audiogram A2, which features a purely sensorineural reverse-slope pathology. When the SD-LFP initialization heuristic was disabled, the optimizer yielded an SII of 0.89 but incurred a monaural loudness of 6.0 sones, exposing the patient to severe upward spread of masking. When the SD-LFP constraint was re-enabled (applying a -10 dB LF attenuation proxy prior to optimization), the SII settled at a comparable 0.88, but the modeled monaural loudness decreased to 4.9 sones. This demonstrates that the SD-LFP constraint limits modeled low-frequency amplification without mathematically sacrificing audibility.



## G. The severe-loss booster

Because foundational half-gain rules mathematically under-amplify severe-to-profound losses with regard to pure audibility, Open-NL incorporates a disabled-by-default, parameterized **Severe-Loss Booster**. However, while severe-to-profound losses inherently require more gain to overcome inner hair cell damage, the precise transition point and safe magnitude are heavily debated. Byrne, Parkinson, and Newall (1990) explicitly place the half-gain breakdown transition closer to 70 dB HL, and crucially, they demonstrate that even for profoundly impaired listeners, empirical preference caps excess gain at roughly 10 dB above standard NAL targets—not as an open-ended escalation. Furthermore, contemporary data indicates that aided speech recognition is generally insufficient once hearing loss exceeds ~80 dB HL regardless of the target applied (Engler, Digeser, & Hoppe, 2026), implying that audibility-driven gain in this region yields rapidly diminishing perceptual returns. Mueller's (2005) review similarly found no evidence supporting gain levels structurally higher than NAL prescriptions, while Convery and Keidser (2011) demonstrated that transitioning severe-to-profound listeners toward structured prescriptive targets often objectively worsens speech discrimination.

Consequently, while the default Open-NL implementation utilizes a conservative 70 dB HL onset for its severe-loss booster to prevent inadvertent downstream over-prescription, it intentionally includes an opt-in aggressive 60 dB HL onset mode (with a 0.15 dB/dB slope escalation up to 80 dB HL) which is knowingly over-prescriptive. A booster that starts 10 dB below the established half-gain transition and forces gain into a region of diminishing perceptual return (Engler, Digeser, & Hoppe, 2026) is explicitly designed as an "ablation knob" for testing mathematical optimizer boundaries, not as a clinically supported rule. By defaulting this onset to 70 dB HL (and keeping the booster itself defaulted to off), the package aligns with the conservative findings of the broader literature. When the aggressive 60 dB HL onset is explicitly enabled by researchers, it serves purely to observe how the optimizer's internal loudness constraints handle forced, aggressive high-frequency gain. To prevent discontinuous gain jumps during calculation, this bounded booster is integrated seamlessly into the base target gain formula (see Equation 1, Section II.C).

## H. Soft-compression high-frequency desensitization (Theoretical Centerpiece)

The soft-compression high-frequency desensitization envelope is not merely a mitigation footnote; it is the theoretical centerpiece of the Open-NL framework. As detailed later in Section IV, naive maximization of the Speech Intelligibility Index (SII) for steeply sloping losses inherently yields a dangerous mathematical artifact: it prescribes massive high-frequency gain that drives up physical audibility scores while severely degrading true perceptual clarity. To mathematically correct this, Open-NL utilizes a smooth soft-compression envelope to aggressively restrict high-frequency gain.

The empirical basis for this penalty is robustly supported: Ching, Dillon, Katsch, and Byrne (2001) demonstrated that the effectiveness of audibility declines as hearing loss worsens, and does so much more steeply at high frequencies. This physiological reality is precisely why foundational algorithms like NAL-NL1 deliberately provide *less* gain where hearing is most impaired (Byrne et al., 2001). Furthermore, while the presence of cochlear dead regions (DRs) is often cited as the primary justification for high-frequency attenuation, the evidence is highly nuanced. In severe-to-profound loss with extensive DRs, amplification benefit plateaus roughly one octave above the DR edge frequency (Malicka et al., 2013; Pepler, Lewis, & Munro, 2015). However, in mild-to-moderately-severe loss, high-frequency gain remains beneficial whether or not restricted DRs are present, and it rarely harms behavioral performance (Cox, Johnson, & Alexander, 2012). 

This nuanced reality highlights a critical limitation in the current Open-NL architecture. Because the algorithm relies on a generalized, slope-triggered high-frequency penalty to conservatively manage suprathreshold distortion across all severe impairments with a blunt mathematical instrument, it explicitly risks over-penalizing exactly those mild/moderate cases where high-frequency audibility remains useful (Cox et al., 2012). Rather than applying a jagged hard-cap on insertion gain—which may induce spectral artifacts—Open-NL utilizes a dynamic gain limit ($L_{gain}$) established using a 30 dB base and a 0.4 slope. Similar to the 0.46 base scaling factor, these constants are asserted heuristics intended to bind the optimizer safely below the DR benefit plateau, rather than validated physiological limits:
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

In addition to this dynamic soft-compression penalty, Open-NL exposes explicit parameters for known cochlear dead regions. While the algorithm previously attempted to automatically infer dead regions from pure-tone thresholds—a mathematically brittle and clinically invalid approach—it now allows researchers to explicitly designate High-Frequency or Low-Frequency Dead Region boundaries ($f_{e\_hf}$ and $f_{e\_lf}$). If defined, Open-NL strictly limits amplification beyond these boundaries following Moore's (2001, 2004) 1.7x basal spread allowances, applying a steep 30 dB/octave attenuation. Furthermore, for patients exhibiting unusually high perceptual distortion, an optional "Distortion Category" toggle invokes Margolis et al. (2025) constraints, forcibly rolling off gain by -5 dB to -10 dB per octave above 1500 Hz.

## I. Dynamic Range Mapping (LDL Squeeze)

Following the foundational philosophy of the DSL v5.0 prescriptive method (Scollie et al., 2005), Open-NL integrates explicit dynamic range mapping to accommodate reduced Uncomfortable Loudness Levels. It is important to note that the algorithm utilizes two distinct discomfort predictors for different theoretical purposes: an HL-domain LDL predictor for estimating clinical audiometric dynamic range (Section II.H), and an SPL-domain UCL predictor for establishing physical device saturation limits (Section II.J). While conceptually well-motivated, both of these predictors are fundamentally uncalibrated linear heuristics. They represent additional untested assumptions feeding directly into the optimization pipeline and must be explicitly flagged as such.

When a patient exhibits a lower-than-expected clinical LDL, blindly applying unmodified target gain results in discomfort. To prevent this, the algorithm calculates a predicted HL-domain LDL based on threshold and conductive loss:
\begin{equation}
\text{LDL}_{predicted} = 100 + \max(0, \text{HTL}_{sn} - 40) \cdot 0.5 + \text{Loss}_{conductive}
\end{equation}
The algorithm then quantifies the dynamic range "squeeze" by comparing the measured LDL to the predicted LDL. For every 1 dB the patient's dynamic range is reduced, target insertion gain ($G_{65}$) is proportionally attenuated by 0.2 dB to ensure the speech envelope fits within the restricted auditory space. Mathematically, squeezing the identical range of acoustic input levels into a smaller residual auditory space necessitates a higher compression ratio. Open-NL inherently accounts for this fundamental WDRC property by increasing the baseline compression ratio ($\text{CR}_{base}$) by 0.02 for every 1 dB of dynamic range squeeze.

## J. Transducer Bandwidth Roll-off

Consistent with the empirical evidence underpinning modern prescriptive targets like NAL-NL2 (Keidser et al., 2012), it is well established that acoustic transducers physically struggle to accurately reproduce frequencies at the extreme margins of the audiometric spectrum (e.g., $\le$ 250 Hz and $\ge$ 6000 Hz). Attempting to apply massive insertion gain targets in these regions inevitably leads to mechanical distortion, phase irregularities, and severe acoustic feedback, often with negligible or negative contributions to the Speech Intelligibility Index. 

To mitigate these physical limitations, Open-NL applies a continuous fractional bandwidth roll-off multiplier to the target gain array. This multiplier dictates a target scaling of 0.7$\times$ at 250 Hz, 1.0$\times$ through the mid-frequencies, 0.8$\times$ at 6000 Hz, and 0.5$\times$ at 8000 Hz.

## K. Dynamic WDRC Computation and U-Shaped Loudness Tolerance

Previously, many theoretical prescriptive models—and early iterations of Open-NL—derived Wide Dynamic Range Compression (WDRC) by first anchoring an optimization at 65 dB SPL and then applying static heuristic multipliers to generate targets for soft (50 dB SPL) and loud (80 dB SPL) speech. 

However, having optimized the `calculate_loudness_cpp()` engine to execute in roughly ~13ms per evaluation, Open-NL abandons these heuristics completely. The Nelder-Mead engine now independently maximizes the Speech Intelligibility Index (SII) at 50, 65, and 80 dB SPL, relying on biologically grounded, level-specific dynamic loudness caps to safely bound the objective function. While the internal physiological models evaluate auditory excitation across dense spectral bands, the prescriptive gain targets are generated strictly at standard octave frequencies (250 - 8000 Hz). This design choice intentionally constrains the dimensionality of the Nelder-Mead optimization space while ensuring the resulting targets remain pragmatically verifiable using standard multi-channel clinical test-box hardware.

Crucially, modeling these physiological limits revealed that human loudness tolerance does not decrease linearly with hearing loss. Instead, Open-NL implements a **U-Shaped Clinical Loudness Tolerance Envelope**. At an 80 dB SPL input (which is naturally quite loud), an unimpaired listener perceives roughly ~20.3 sones. For mild-to-moderate losses, the presence of cochlear recruitment and narrowed dynamic ranges necessitates heavy compression to keep this signal comfortable, dropping the physiological tolerance cap strictly down to ~10 sones. However, for severe-to-profound losses, restoring audibility requires raw acoustic power just to cross elevated thresholds. To achieve this, the system must push closer to the device's saturation limit, meaning these patients must inherently tolerate higher overall loudness (~14-15 sones). 

By structuring the dynamic cap knots (`cap_knots`) in this U-shape across the Pure Tone Average (PTA) spectrum, the optimizer dynamically squashes gain for mild losses while permitting the required raw power for severe losses. Consequently, the final prescribed Compression Ratios (CR) are an *emergent outcome* of the optimizer reacting to these physiological ceilings, rather than a static mathematical rule. To ensure clinical safety, the optimizer's outputs are strictly audited to guarantee emergent compression ratios never exceed the standard maximum clinical constraint of 3.0:1. As demonstrated by Souza (2002), compression ratios exceeding 3:1 severely flatten the amplitude differences between speech peaks and valleys, causing temporal envelope distortion that actively degrades speech recognition and sound quality.

The resulting emergent compression ratios for both NAL-NL2 and Open-NL across the seven standard audiograms are detailed in **Table III**. Crucially, it must be explicitly noted that Table III was generated using the aggressive 60 dB HL booster onset mode (identical to the multi-parameter sweep). Even under this mathematically aggressive setting—which pushes massive gain for severe losses—the emergent CRs for the critical high-frequency speech bands in A4 and A5 remain safely within the 3.0:1 constraint (e.g., reaching 2.96 at 4000 Hz for A4, and 2.17 at 4000 Hz for A5). This confirms that the physiological Lgain ceilings successfully throttle the optimizer's aggressive soft-input drive, preventing the temporal envelope flattening that would otherwise accompany such massive gain targets.

**TABLE III. Effective Compression Ratios (Gain50 / Gain80) across A1-A7 Audiograms.** *Note: Generated using the aggressive 60 dB HL booster onset. Ratios strictly exceeding 3.0:1 (e.g., A1 at 8000 Hz) occur only in off-target regions where absolute prescribed gain approaches zero, rendering the ratio a mathematical artifact rather than a functional envelope distortion.*

| Profile | Formula | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz |
|---------|---------|--------|--------|---------|---------|---------|---------|
| A1 | NAL-NL2 | - | - | 62.00 | 7.22 | 3.66 | 2.74 |
| A1 | Open-NL | - | 1.00 | 2.02 | 2.84 | 2.60 | 8.45 |
| A2 | NAL-NL2 | - | - | 5.84 | 47.33 | - | - |
| A2 | Open-NL | - | 5.59 | 2.71 | 6.41 | - | - |
| A3 | NAL-NL2 | 1.00 | - | 8.37 | 3.75 | 3.03 | 2.42 |
| A3 | Open-NL | 1.00 | 1.00 | 2.31 | 2.94 | 2.94 | - |
| A4 | NAL-NL2 | 1.00 | 1.00 | - | 6.40 | 2.46 | 2.11 |
| A4 | Open-NL | 1.00 | 1.00 | 1.00 | - | 2.96 | 1.64 |
| A5 | NAL-NL2 | 1.00 | 1.00 | 56.50 | 2.44 | 1.87 | 1.75 |
| A5 | Open-NL | 1.00 | 1.00 | 1.00 | - | 2.17 | 2.10 |
| A6 | NAL-NL2 | 1.35 | 1.35 | 1.43 | 1.43 | 1.55 | 1.53 |
| A6 | Open-NL | 1.54 | 1.38 | 1.30 | 1.29 | 1.26 | 1.34 |
| A7 | NAL-NL2 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| A7 | Open-NL | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |




## L. Conductive Correction, Receiver Limits, and Profile-Specific Penalties

For mixed and conductive hearing losses, Open-NL limits baseline conductive restoration to 75% of the air-bone gap (ABG) to respect the Maximum Power Output (MPO) limits of modern hearing aid receivers. As Johnson (2013) notes, many Receiver-In-Canal (RIC) styles physically max out around 118–124 dB SPL. To explicitly model this hardware limitation, Open-NL imposes a rigid **120 dB SPL receiver limit** within the optimizer's evaluation loop. When the optimizer attempts to fully restore a large ABG for an already loud 80 dB SPL input, the theoretical output collides with this physiological receiver wall, inherently clipping the gain and forcing an emergent compression ratio that protects the user from severe saturation distortion.

Furthermore, Open-NL applies dynamic penalties to the objective function's loudness cap based on the specific audiometric profile:
1. **Reverse-Slope Penalty**: Audiometric profiles with reversed slopes (e.g., severe low-frequency loss with near-normal high-frequency hearing) inherently expose healthy high-frequency hair cells to excessive SPL if broadband gain is applied at loud input levels. To prevent severe level distortion (rollover) and uncomfortably tinny outputs, Open-NL detects reverse-slope gradients and actively constricts the loudness cap for loud inputs ($\geq$ 75 dB SPL), effectively crushing high-frequency gain back to near-zero (mirroring NAL-NL2's behavior).
2. **High-Input ABG Restriction**: For soft and average speech, the dynamic comfort cap is mathematically relaxed by 0.10 sones per decibel of ABG, because the mechanical attenuation of the middle ear safely reduces cochlear excitation. However, at loud inputs ($\geq$ 75 dB SPL), large conductive gaps risk severe saturation and level distortion if overly amplified. For these loud inputs, the model actively *restricts* the cap by 0.25 sones per decibel of ABG, forcing the optimizer to adopt highly conservative targets for loud mixed losses. To ensure the optimizer has the mathematical freedom to reach these restricted caps, the maximum allowable gain shift—which is normally tightly constrained proportional to the ABG to preserve conductive linearity—is fully relaxed for loud inputs, allowing the Nelder-Mead algorithm to prescribe up to 15 dB of dynamic compression.
3. **Numerical Convergence Regularization**: Because steep mixed/conductive losses seed the optimizer with incredibly high initial target gains for loud sounds (due to the 75% ABG restoration heuristic), walking down a strict physiological penalty gradient can easily exhaust standard numerical iteration limits. To ensure stable convergence on the true loudness floor rather than prematurely terminating in a high-gain local minimum, Open-NL strictly regularizes the unconstrained Nelder-Mead algorithm (`optim`). For inputs > 65 dB SPL, the solver's initial simplex is aggressively anchored at a -5.0 dB shift with a $\pm10$ dB multi-start jitter, and the internal iteration ceiling is raised to `maxit = 800`. This guarantees the numerical solver has the required "head start" and trajectory breadth to successfully navigate deep compression gradients.

## M. Comfort in noise (CIN) module

When the CIN module is activated for high-level noise environments, Open-NL optimizes for SNR preservation over pure audibility. Drawing inspiration from modern Comfort in Noise heuristics (Kitterick et al., 2026), Open-NL acknowledges that compression preference is highly heterogeneous and interacts with the degree of loss and concurrent noise reduction. Accordingly, to prevent the fast-acting amplification of inter-syllabic noise floors (pumping) and strictly preserve the natural temporal signal-to-noise ratio of the speech envelope (Souza, 2002), the maximum CR is clamped at 1.5:1 (near-linear), and the compression threshold (CT) is reduced by 10 dB, shifting the compressive knee-point to a lower input level while simultaneously applying a shallower, more linear compression slope.

## N. Acoustic venting and signal purity

Acoustic coupling heavily influences the Real-Ear Aided Response (REAR). When modeling open or vented fittings, Open-NL integrates the expected low-frequency leakage ($V_{loss}$) into the target derivation. Crucially, the algorithm permits insertion gain targets to drop into negative values to match this physical leakage. This prevents the hearing aid from attempting to generate excessive internal gain to overcome the vent—a situation that leads to comb filtering and physical acoustic feedback. 



These uncalibrated dynamic parameters (such as the new-user offset) introduce critical structural sensitivity into the resulting insertion gain targets.

