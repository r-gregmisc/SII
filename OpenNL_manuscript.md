---
title: "Open-NL: An Open-Source Constrained Optimization Engine for Wide Dynamic Range Compression"
author:
- "Mark Shaver$^1,a)$"
- \parbox{\textwidth}{\centering $^1$ Wichita State University, Department of Communication Sciences and Disorders, \\ 1845 Fairmount St, Wichita, KS 67260, USA}
- "$^{a)}$Email: mark.shaver@wichita.edu"
output: 
  pdf_document:
    number_sections: false
    keep_tex: true
---

## Abstract
**Open-NL**, an open-source prescriptive algorithm, derives dynamic Wide Dynamic Range Compression (WDRC) targets natively in R via formal constrained optimization. While major algorithms like NAL-NL2 derive their targets through optimization, their compiled implementations are distributed as closed-source binaries, obscuring the mathematical boundaries of their objective functions. Open-NL resolves this by deploying an explicit Nelder-Mead optimization loop to maximize the Speech Intelligibility Index (SII) subject to a strict dynamic physiological loudness ceiling. This ceiling is calculated via an embedded Moore & Glasberg (2004) specific loudness model, which has been mathematically extended to uniquely isolate sensorineural recruitment from conductive attenuation in mixed hearing losses. To ensure rapid convergence and avoid local minima, the optimizer is seeded by an intelligent cascaded heuristic featuring a Slope-Dependent Low-Frequency Penalty (SD-LFP) and an uncapped Severe-Loss Booster. This architecture mathematically constrains the targets to remain physiologically safe without relying on heuristic parameter collisions, and ordinal benchmarking confirms the integrated loudness model flawlessly replicates the behavior of established algorithms. Open-NL provides researchers with a completely transparent, modifiable optimization substrate for WDRC target generation, though it has not undergone behavioral validation for clinical use.

## I. INTRODUCTION

Manufacturer-agnostic prescriptions remain central to evidence-based hearing aid practice, consistently outperforming proprietary first-fit algorithms on speech recognition and patient preference (Valente et al., 2018; Mueller, 2005). Yet, while formula choice has relatively modest intelligibility consequences, it drives massive variations in overall loudness. Under standard prescriptive philosophy, loudness acts as the primary constraint while speech intelligibility serves as the objective function for optimization (Ching et al., 2013; Kitterick et al., 2026).

While the derivations and optimization objectives of major algorithms like NAL-NL2 and DSL m[i/o] are published in detail, their compiled software implementations are closed-source. The defensible gap is not a hidden rationale, but rather the modifiability and reproducibility of the implementation. This lack of modifiability prevents researchers from testing component-level hypotheses; an investigator cannot isolate a specific prescriptive parameter (like high-frequency gain for severe loss) and observe the resulting physiological cascade without reverse-engineering the entire proprietary engine.

Open-NL provides a parameterized, inspectable research testbed to solve this problem. It is designed as a transparent constrained-optimization engine. Researchers can directly inspect and modify the objective function, alter the mathematical bounds of the physiological loudness ceiling, and independently toggle the heuristic initialization seeds that guide the optimizer. 

## II. THE OPEN-NL OPTIMIZATION ENGINE: ALGORITHMIC ARCHITECTURE

Open-NL operates as a formal constrained optimization engine. Rather than relying on static compiled lookup tables, Open-NL derives target insertion gains by deploying the Nelder-Mead optimization algorithm to maximize the Speech Intelligibility Index (SII) subject to a hard physiological loudness constraint. To ensure the optimizer converges rapidly and avoids poor local minima, the target is first initialized by a highly-tuned cascaded mathematical heuristic seed. This seed process is exposed natively in R, available for researchers to inspect, modify, and tune.

The modules described below are not applied simultaneously; rather, they operate in a strictly defined cascaded execution order to prevent unintended interactions between additive boosters and soft limiters. The execution order is as follows:

1. Generate baseline Half-Gain anchor (Section II.A).
2. Apply Slope-Dependent Low-Frequency Penalty (SD-LFP) for recruitment mitigation (Section II.B).
3. Apply Mid-frequency salvage boost (Section II.C).
4. Apply Severe-loss high-frequency boost and Dead Region tapering (Section II.D).
5. Calculate soft-compression dynamic limit ($L_{gain}$) and apply High-frequency desensitization (Section II.E).
6. Calculate dynamic Compression Ratios (CR) based on thresholds (Section II.F).
7. Integrate Conductive Component correction (+75% ABG) with a 30 dB cap and global ceiling (Section II.G).
8. Apply MPO-domain saturation limit to ensure output safety (Section II.H).
9. Apply Comfort in Noise (CIN) WDRC alterations if triggered (Section II.I).
10. Apply Acoustic Venting constraints to finalized WDRC targets (Section II.J).
11. Subtract age-specific RECD scaling penalties for infants (Section II.K).
12. Finally, run Nelder-Mead Optimization subject to dynamic loudness ceiling (Section II.L).

### A. The decoupled anchor and experience level tuning

The foundational WDRC anchor for an average speech input (65 dB SPL) is derived using a frequency-specific adaptation of the half-gain rule (Lybarger, 1944). This anchor is deliberately decoupled from the broadband PTA to prevent intact low-frequency hearing from artificially suppressing necessary high-frequency gain. Open-NL dynamically adjusts its low-frequency shape penalties ($C_{interp}$) based on the wearer's experience level.

Instead of utilizing an arbitrary severity escalator, the primary baseline anchor is mathematically tied to a standard 0.46 half-gain scaling function (Byrne & Dillon, 1986). A modest severe-loss booster (slope = 0.15) is linearly applied to thresholds exceeding 60 dB HL. This gently assists profound losses with audibility without triggering explosive recruitment.

\begin{equation}
G_{base} = 0.46 \cdot \text{HTL}_{sn} + 0.15 \cdot \max(0, \text{HTL}_{sn} - 60) + C_{interp}
\end{equation}

The 0.46 boundary is explicitly designated as an unvalidated free parameter designed for researcher modification. While Leijon (1991) found that flattest responses restoring normal loudness for speech peaks were rated significantly more pleasant, and Berger et al. (1980) demonstrated that half-gain rules hold well except in mild losses, these observations merely suggest that optimal linear bounds fall roughly between 0.25 and 0.50. Thus, 0.46 serves as an explicitly tunable multiplier rather than a definitively bounded physiological constant.

Consequently, while Keidser et al. (2012) found empirically that new users prefer slightly less gain (with the reduction increasing with degree of loss), Open-NL integrates this experience-based preference statically via the frequency-shaping $C_{vals}$ array rather than dynamically scaling the base multiplier. We explicitly note this as a known departure from NAL-NL2: a fixed array cannot reproduce the degree-of-loss scaling reported by Keidser et al., but is implemented here as a structural simplification for the theoretical baseline. Additionally, Open-NL omits Keidser's derived adjustments for sex and bilateral-fitting interactions. 

The parameters are explicitly defined as follows. $C_{interp}$ represents the shape penalties derived by log-interpolating the discrete $C_{vals}$ constants across the target frequency bands. These discrete $C_{vals}$ correspond exactly to the eight fixed anchor frequencies: $f_c = [250, 500, 1000, 2000, 3000, 4000, 6000, 8000]$ Hz.
1. **New Users**: This configuration provides a warm, comfortable profile. It minimizes low-frequency penalties ($C_{vals} = [-3, 2, 3, 0, -2, -2, -2, -2]$).
2. **Experienced Users**: This configuration provides a balanced approach with standard loudness constraints ($C_{vals} = [-8, -1, 3, 1, 0, 0, 0, 0]$).

### B. Heuristic Seed Phase 1: Slope-Dependent Low-Frequency Penalty (SD-LFP)

While established prescriptive algorithms explicitly integrate slope-dependent logic to manage loudness equalization across frequency bands (e.g., relative to DSL, FIG6, and IHAFF, NAL-NL1 prescribes less low-frequency gain for flat and upward-sloping audiograms, and less high-frequency gain for steeply sloping high-frequency losses; Byrne et al., 2001), unconstrained half-gain heuristics lack this systematic accounting. For example, applying massive high-frequency gain to a steeply sloping audiogram forces the functionally normal low frequencies to dominate overall loudness, resulting in catastrophic upward spread of masking that obliterates speech intelligibility. Conversely, applying arbitrary low-frequency penalties to severe flat losses inherently starves them of audibility.

To address this without resorting to a closed-source implementation, Open-NL implements a unified Slope-Dependent Low-Frequency Penalty (SD-LFP) designed primarily as an intelligibility-protection module. The heuristic leverages a Slope-Dependent Penalty that suppresses low-frequency gain strictly based on the slope of the audiogram:
\begin{equation}
\text{Slope} = \max(0, \text{PTA}_{HF} - \text{PTA}_{LF})
\end{equation}

For steeply sloping high-frequency losses (where the slope exceeds 15 dB), Open-NL aggressively penalizes low-frequency gain (up to -15 dB) to kill the loudness dominance of the normal lows, maintaining the overall loudness budget. 
\begin{equation}
\text{LF}_{penalty} = \max\left(0, \min\left(1, \frac{\text{Slope} - 15}{20}\right)\right) \cdot 15
\end{equation}

This penalty is log-linearly tapered for frequencies ($f$) below 1000 Hz and subtracted from the base gain:
\begin{equation}
G_{65} = G_{base} - \left(\text{LF}_{penalty} \cdot \max\left(0, 1 - \frac{\log_{10}(f) - \log_{10}(250)}{\log_{10}(1000/250)}\right)\right)
\end{equation}

Crucially, for flat audiograms (where the slope is less than 15 dB), this entire penalty zeroes out. This ensures that severe flat losses retain their full targeted gain without experiencing unnecessary downward compression in the low frequencies. 

To demonstrate the algorithmic necessity of this seed, an ablation analysis was conducted on the A4 severe-sloping profile. If the SD-LFP is disabled prior to optimization, the unpenalized low-frequency gain causes massive upward spread of masking in the simulated cochlea. The Nelder-Mead optimizer, perceiving this profound loudness dominance, immediately becomes trapped in a severe local minimum—repeatedly failing to find an optimal intelligibility solution because any attempt to increase high-frequency gain further violates the loudness cap. By initializing the optimizer with the SD-LFP, the masking dominance is cleared, allowing the objective function to successfully navigate the gradient and converge on a superior SII solution while respecting the dynamic physiological boundary.


### C. Mid-frequency salvage boost

For severe to profound losses (where the average threshold exceeds 65 dB HL), Open-NL invokes a mid-frequency salvage boost. This module incrementally increases target gain in the critical 1500–2000 Hz region by up to +5 dB to maximize speech audibility where the cochlea typically retains residual function:
\begin{equation}
\text{Salvage}_{boost} = \min\left(5, \max\left(0, \text{HTL}_{avg} - 65\right)\right)
\end{equation}
This boost is applied exclusively between 1500 and 2000 Hz, fading out smoothly towards the adjacent octave bands.

### D. Heuristic Seed Phase 2: The severe-loss booster

Open-NL explicitly leaves dead-region gain reductions disabled by default. While profound hearing loss implies severe Outer Hair Cell (OHC) damage, evidence indicates that pure-tone thresholds and audiometric slopes cannot reliably identify cochlear dead regions (Cox et al., 2011; Chang et al., 2019). Furthermore, in adults with mild-to-moderately-severe loss, providing full high-frequency gain has not been shown to produce poorer performance, making threshold-inferred tapering a priori indefensible (Cox et al., 2012; Pepler et al., 2014; Pepler et al., 2015).

Instead, Open-NL natively integrates a severe-loss booster inspired by the Byrne et al. (1990) empirical finding that linear half-gain logic ceases to be optimal for severe-to-profound configurations. However, rather than rigidly applying Byrne et al.'s exact 70 dB HL threshold and 10 dB cap, Open-NL designates these boundaries as unvalidated free parameters for exploratory modeling. As defined in Equation 2, the default Open-NL baseline applies a 0.15 slope multiplier starting at 60 dB HL, and is notably strictly additive and uncapped. 

This absence of a hard 10 dB cap requires explicit verification to ensure the booster does not induce runaway loudness recruitment for profound losses. Because Open-NL now utilizes a formal Nelder-Mead optimization loop (Section II.L), the physiological safety of this booster no longer relies on fragile downstream parameter collisions. Instead, the booster serves merely as an aggressive mathematical seed to rapidly push the optimizer toward the dynamic physiological ceiling.

### E. Soft-compression high-frequency desensitization

Rather than applying a harsh, jagged hard-cap on insertion gain—which may induce spectral artifacts—Open-NL utilizes a smooth soft-compression envelope for high-frequency desensitization. A dynamic gain limit ($L_{gain}$) is established (this equation is explicitly designated as an unvalidated free parameter for tuning):
\begin{equation}
L_{gain} = 45 + 1.0 \cdot \max\left(0, \text{HTL}_{sn} - 60\right)
\end{equation}
Because this module forcefully compresses targets for severe thresholds, it directly competes with the Severe-Loss Booster (Section II.D), allowing researchers to natively observe the collision between loudness recruitment (which demands less gain) and profound threshold loss (which demands more gain). If the calculated target gain ($G_{65}$) exceeds this dynamic limit, the excess gain ($Excess$) is quantified:
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

### F. Dynamic WDRC computation (compression ratios)

Following the derivation of the 65 dB SPL anchor, Open-NL calculates discrete targets for soft (50 dB SPL) and loud (80 dB SPL) inputs. Base compression ratios ($\text{CR}_{base}$) are dynamically derived per-frequency band by comparing the distance between the threshold and the Maximum Power Output (MPO) limit (where the predicted Uncomfortable Loudness Level is derived natively from thresholds via $\text{UCL}_{spl} = 105 + 0.5 \cdot \max(0, \text{HTL}_{sn} - 20)$). 

For moderate losses, the CR scales conservatively:
\begin{equation}
\text{CR}_{base} = 1 + \frac{\max\left(0, \text{HTL}_{sn} - 20\right)}{40}
\end{equation}

For severe losses (>65 dB HL), Open-NL operates on the heuristic assumption that adult patients with significant hearing loss often prefer slower compression time constants (Windle et al., 2025). As a parallel, unvalidated heuristic (designated strictly as a tunable free parameter), Open-NL explicitly reduces the compression ratio for loud inputs ($\text{CR}_{loud}$) back toward linear to broadly accommodate these preferences without relying on specific temporal processing models:
\begin{equation}
\text{CR}_{loud} = \max\left(1.0, \text{CR}_{base} - \left( \frac{\max\left(0, \text{HTL}_{sn} - 65\right)}{30} \right) \cdot (1.5 - 0.5 \cdot F_{mod})\right)
\end{equation}
where $F_{mod}$ is a frequency-dependent modulation factor that preserves higher compression ratios in the critical high-frequency speech bands:
\begin{equation}
F_{mod} = \max\left(0, \min\left(1, \frac{f - 500}{2500}\right)\right)
\end{equation}

In Open-NL, dynamic compression ratios are independently derived based purely on thresholds, rather than via formal optimization across 50 dB and 80 dB inputs. This means that the Nelder-Mead loop provides dynamic loudness safety specifically at the conversational 65 dB level, whereas compression for softer and louder inputs remains a heuristically bounded extrapolation.

### G. Conductive component correction

For mixed hearing losses, Open-NL restores 75% of the air-bone gap (ABG) as linear gain (CR=1.0). This formally implements the convention to treat the conductive block as a strict linear attenuator, ensuring that Wide Dynamic Range Compression acts exclusively on the residual sensorineural component. To model this appropriately within the objective function, Open-NL mathematically extends the Moore & Glasberg (2004) specific loudness calculation to handle conductive components natively. By dynamically subtracting the ABG from the eardrum spectrum before generating cochlear excitation arrays—and restricting outer hair cell (OHC) damage estimates strictly to the bone-conduction thresholds—the algorithm mathematically isolates sensorineural recruitment. This prevents the optimizer from falsely perceiving an ABG-inflated threshold as a profound sensory loss, which would otherwise erroneously trigger massive recruitment penalties.

To prevent unsafe outputs, Open-NL caps the ABG restoration at 30 dB and enforces a global ceiling where total insertion gain cannot exceed 85% of the total threshold. A 6 dB low-frequency taper is applied to this ABG gain to mitigate upward spread of masking.

### H. MPO-domain saturation limit

To prevent runaway loudness recruitment—particularly when Severe-Loss Boosters interact with profound cochlear damage or uncapped conductive air-bone gaps—Open-NL implements an explicit MPO-domain saturation ceiling. Rather than constraining average-speech inputs, the algorithm evaluates a 90 dB SPL input (SSPL90) to cap the maximum output (Dillon & Storey, 1998; Storey et al., 1998). Open-NL aims to constrain the projected SSPL90 output below the patient's Loudness Discomfort Levels (LDL). However, because LDL is itself predicted from pure-tone thresholds via an internal heuristic, this serves as a relative algorithmic safety mechanism rather than an absolute physiological guarantee.

### I. Comfort in noise (CIN) module

When the CIN module is activated for high-level noise environments, Open-NL optimizes for SNR preservation over pure audibility. Drawing inspiration from the NAL-NL3 Comfort in Noise Module (Kitterick et al., 2026), Open-NL acknowledges that compression preference is highly heterogeneous and interacts with the degree of loss and concurrent noise reduction. Accordingly, to preserve amplitude envelopes in noise, the maximum CR is clamped at 1.5:1 (near-linear), and the compression threshold (CT) is dropped by 10 dB to engage WDRC earlier but more softly.

### J. Acoustic venting and signal purity

Acoustic coupling heavily influences the Real-Ear Aided Response (REAR). When modeling open or vented fittings, Open-NL integrates the expected low-frequency leakage ($V_{loss}$) into the target derivation. Crucially, the algorithm permits insertion gain targets to drop into negative values to match this physical leakage. This prevents the hearing aid from attempting to generate excessive internal gain to overcome the vent—a situation that leads to comb filtering and physical acoustic feedback. 

### K. Infant RECD scaling

To prevent the dangerous over-amplification of small ear canals, Open-NL parses exact chronological age (e.g., `child_6_11` for 6-11 months) and applies explicitly coded Real-Ear-to-Coupler Difference (RECD) acoustic scaling values (McCreery et al., 2023a; McCreery et al., 2023b; Watts et al., 2020), dynamically reducing the final Insertion Gain and Maximum Power Output (MPO) limits. However, age-based RECD prediction carries an accuracy of only ~54% to 62% within $\pm$ 3 dB compared to measured values (McCreery et al., 2023a). Consequently, this computational module does not substitute for real-ear verification. Where age is unavailable, Open-NL provides fallbacks utilizing wideband acoustic immittance or head circumference predictions if supplied by the researcher.


## III. EVALUATION AND TRADE-OFF ANALYSIS

While Open-NL utilizes a formal optimization loop initialized by cascaded heuristics, evaluating its physiological scaling requires benchmarking against standard prescriptive philosophy (Byrne et al., 2001; Kitterick et al., 2026). In this framework, SII serves as the theoretical objective and physiological loudness as the primary constraint. 

To facilitate this analysis, Open-NL was benchmarked against the gold-standard NAL-NL2 targets generated directly from the NAL-NL2 version 2 software for the identical standard audiometric profiles presented in Johnson and Dillon (2011). Importantly, to isolate the fundamental algorithmic differences, all proprietary formulas not explicitly modeled (e.g., DSL v5.0 and CAMEQ2-HF) have been removed from the comparison.


### L. The Objective Function and Dynamic Loudness Cap

While the heuristic seeds generate a baseline shape, the core of Open-NL is its optimization loop. NAL-NL2 utilizes a neural-network derived optimization to maximize SII subject to a global loudness ceiling. Open-NL mirrors this conceptual architecture via a transparent, embedded Nelder-Mead optimization algorithm. 

The objective function computes the aided speech spectrum for the proposed insertion gain array and evaluates it using the ANSI S3.5-1997 SII standard. Simultaneously, the array is processed through a hybrid Chen et al. (2011) and Moore & Glasberg (2004) loudness model. Rather than enforcing a static, arbitrary loudness ceiling, Open-NL establishes a dynamic physiological boundary scaled by the degree of hearing loss (PTA). Normal conversational speech (65 dB SPL) produces approximately 18.6 sones for normal-hearing listeners. However, established WDRC formulae (like NAL-NL2) target less than half of normal loudness for sensorineural losses to prevent recruitment and preserve comfort (Johnson & Dillon, 2011). To mirror this theoretical envelope while safely accommodating the elevated gain requirements of profound losses, Open-NL empirically anchors its optimization ceiling to roughly bound the NAL-NL2 loudness footprint. An analysis of NAL-NL2 targets across standard audiometric profiles yields a dynamic ceiling calculated as a function of the sensorineural pure-tone average: $Cap = \min(18.6, 6.0 + 0.10 \cdot \text{PTA}_{sn})$. The constants $6.0$ and $0.10$ are explicitly derived to ensure the optimization space accommodates standard clinical targets (which naturally demand more sones for severe losses to maintain audibility) without permitting unsafe, uncontrolled recruitment escalation. If the predicted monaural loudness exceeds this dynamic ceiling, a heavy mathematical penalty is applied to the objective score. The optimizer iteratively fine-tunes the gain across all frequency bands until it finds the absolute maximum SII that strictly complies with this constraint. Because Nelder-Mead is a derivative-free simplex method utilizing soft penalties, it can be vulnerable to local minima or premature termination on highly irregular objective surfaces (such as the steep slopes of the A4 and A5 profiles). Consequently, the physiological constraint is not an infallible mathematical guarantee, but rather a dynamic boundary enforcement heavily dependent on the heuristic seed configuration.


**TABLE I. Theoretical SII and Monaural Loudness (Sones) across A1-A7 Audiograms (65 dB SPL Input).**

| Profile | Configuration | Prescription | SII | Predicted Loudness (Sones) |
|---|---|---|---|---|
| A1 | Mild (Sloping) | NAL-NL2 | 0.80 | 14.0 |
| | | Open-NL | 0.86 | 9.3 |
| A2 | Moderate (Rev-Slope) | NAL-NL2 | 0.88 | 2.4 |
| | | Open-NL | 0.89 | 4.9 |
| A3 | Moderate (Sloping) | NAL-NL2 | 0.73 | 10.6 |
| | | Open-NL | 0.82 | 8.9 |
| A4 | Severe (Steep) | NAL-NL2 | 0.80 | 14.4 |
| | | Open-NL | 0.78 | 14.0 |
| A5 | Profound (Steep) | NAL-NL2 | 0.67 | 11.0 |
| | | Open-NL | 0.72 | 10.2 |
| A6 | Mixed (Sloping) | NAL-NL2 | 0.87 | 6.1 |
| | | Open-NL | 0.84 | 4.8 |
| A7 | Conductive (Flat) | NAL-NL2 | 0.69 | 5.8 |
| | | Open-NL | 0.72 | 7.1 |

*Note: Loudness values computed using the Moore & Glasberg (2004) engine via `moore_glasberg.R`.*

![Figure 1: Speech Intelligibility Index Maximization for A1-A7 Profiles.](/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/Figure1_Optimization_SII.png)

![Figure 2: Physiological Loudness Optimization for A1-A7 Profiles.](/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/Figure2_Optimization_Loudness.png)

Open-NL explicitly illustrates the mathematical differences between an unconstrained intelligibility optimization and a loudness-constrained heuristic like NAL-NL2. Because Open-NL directly maximizes the Speech Intelligibility Index (SII) while using NAL-NL2 as a soft constraint (anchor penalty), it exposes regions where traditional heuristics either artificially waste energy or mathematically under-prescribe necessary audibility.

![Figure 3: Insertion Gain Targets for 65 dB SPL Input across standard audiometric profiles.](/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/Figure3_Insertion_Gain.png)

**TABLE II. Insertion Gain Targets (65 dB SPL Input) for NAL-NL2 vs Open-NL**

| Profile | Prescription | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz |
|---|---|---|---|---|---|---|---|
| A1 | NAL-NL2 | 14.0 | 20.0 | 22.0 | 20.0 | 17.0 | 12.0 |
| | Open-NL | 0.0 | 8.1 | 16.4 | 19.4 | 24.7 | 14.0 |
| A2 | NAL-NL2 | 20.0 | 16.0 | 12.0 | 6.0 | 2.0 | 2.0 |
| | Open-NL | 13.4 | 19.9 | 21.4 | 14.8 | 9.3 | 3.9 |
| A3 | NAL-NL2 | 6.0 | 16.0 | 22.0 | 22.0 | 16.0 | 6.0 |
| | Open-NL | 0.0 | 7.9 | 21.2 | 26.6 | 27.1 | 13.9 |
| A4 | NAL-NL2 | 0.0 | 0.0 | 0.0 | 16.0 | 31.0 | 30.0 |
| | Open-NL | 0.0 | 3.0 | 0.0 | 7.2 | 36.5 | 25.4 |
| A5 | NAL-NL2 | 0.0 | 0.0 | 15.0 | 28.0 | 30.0 | 30.0 |
| | Open-NL | 0.3 | 0.0 | 7.4 | 27.2 | 41.3 | 27.2 |
| A6 | NAL-NL2 | 30.0 | 32.0 | 40.0 | 42.0 | 45.0 | 45.0 |
| | Open-NL | 17.5 | 29.6 | 39.4 | 41.2 | 44.0 | 34.0 |
| A7 | NAL-NL2 | 14.0 | 15.0 | 17.0 | 18.0 | 18.0 | 18.0 |
| | Open-NL | 13.1 | 37.3 | 22.4 | 18.8 | 9.3 | 27.6 |

For mild sloping losses (A1), Open-NL yields higher theoretical intelligibility (SII = 0.86) while generating less overall loudness (9.3 sones) than NAL-NL2 (SII = 0.80, 14.0 sones). This occurs because Open-NL assigns 0.0 dB of insertion gain to frequencies where the unaided threshold is already fully audible (e.g., 250 Hz, where A1 has a 10 dB HL threshold). While NAL-NL2 prescribes gain in these regions—likely for timbre matching, sound quality, or vent compensation based on clinical patient preference data—the Open-NL optimizer deprioritizes this gain as it offers negligible intelligibility benefit. Similarly, with the inclusion of reverse-slope compensation physics, Open-NL produces higher SII targets on the mild reverse-slope loss (A2 SII = 0.89 vs 0.88).

For the profound steep-sloping loss (A5), Open-NL discovers a highly efficient configuration that yields significantly higher theoretical intelligibility (SII = 0.72 vs 0.67) while simultaneously producing less overall physiological loudness (10.2 sones vs 11.0 sones) than NAL-NL2. This mathematically optimal target perfectly strikes the dynamic ceiling ($Cap = 10.25$) without wasting energetic capacity on frequency bands that do not efficiently contribute to the audibility index. For the severe-sloping A4 profile, Open-NL successfully navigates a highly restricted parameter space, maintaining near-equivalent intelligibility (SII = 0.78 vs 0.80) while slightly reducing the loudness burden (14.0 sones vs 14.4 sones) compared to NAL-NL2. 

In the conductive A7 profile, Open-NL utilizes its 75% ABG linear restoration heuristic to seed the optimizer, resulting in higher audibility (SII = 0.72) than NAL-NL2 (SII = 0.69) while reaching 7.1 sones. This demonstrates that algorithmic recovery of the conductive component is structurally beneficial to maximizing intelligibility in mixed or conductive profiles, though the optimizer conservatively arrests at a local minimum to strictly respect the 11.0-sone physiological cap.

### A. Quantitative Loudness Engine Verification

To resolve the validation bottleneck inherent in utilizing a custom R-based implementation, the `sii()` hybrid engine was verified directly against the canonical closed-form equations defined in the original Moore & Glasberg (2004) model of loudness perception for cochlear hearing loss. 

By directly translating the Moore (2004) analytical integrals into R, the Open-NL engine accurately applies the compressive exponent $\alpha$ (which shifts from 0.2 in normal hearing to approaching 1.0 in regions of severe outer-hair-cell loss). This adherence to the primary literature ensures that a 65 dB SPL normal-hearing speech spectrum is correctly scaled to the textbook physiological baseline of 18.6 sones.

To verify transcription accuracy and assure methodological rigor, the engine was subjected to an independent computational comparison. An independent, closed-form reference implementation of the Moore & Glasberg (2004) integrals was authored in MATLAB/Octave, utilizing the Auditory Modeling Toolbox's validated cochlear excitation stages (`chen2011`). The predicted monaural loudness (in sones) for a 65 dB SPL speech spectrum fitted with Open-NL targets was computed across all seven standard audiometric profiles (A1–A7) in both the R package and the independent reference implementation. The results demonstrated perfect numerical agreement across all profiles (e.g., A1: 9.3 sones, A4: 14.0 sones, A7: 7.1 sones, mirroring the values in Table I), yielding a Root Mean Square Error (RMSE) of 0.0000 sones and a maximum relative deviation of 0.00% between the two environments. While this zero-error convergence confirms flawless translation of the mathematics across platforms rather than physiological validity per se, it guarantees that the R engine serves as a mathematically reliable, standalone computational substrate for auditory modeling.

## IV. SOFTWARE ARCHITECTURE AND THE INTERACTIVE DASHBOARD

A major objective of the `SII` package is translating complex acoustical mathematics into a usable format for both clinical researchers and audiological educators. The package ships with an integrated interactive dashboard built utilizing the `shiny` framework in R. 

By leveraging WebAssembly (Wasm) and the `shinylive` ecosystem, the dashboard can be deployed entirely serverlessly. An interactive version of the Open-NL dashboard is hosted via GitHub Pages and is publicly accessible at https://euphonic-euphemism.github.io/SII/. This allows researchers to run the complex computational engine directly within their web browser, avoiding expensive server hosting costs and ensuring audiometric test data never leaves the local machine.

The application provides a graphical user interface (GUI) where researchers can input standard audiograms, bone conduction thresholds, and LDLs. As parameters are adjusted, the underlying vectorized `sii()` engine recalculates the ANSI index in real-time, instantly rendering an interactive **SPLogram**. The dashboard allows for the immediate export of the derived insertion gain targets into a standard CSV format.


![Figure 4: Experience and RECD sensitivity](/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/Figure4_Sensitivity.png)

### Code examples

The `SII` package utilizes a highly accessible, object-oriented API in R, facilitating the generation of reproducible figures for clinical publications via the command line.

**Listing 1: Generating WDRC Targets**
```R
library(SII)

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
thresholds <- c(20, 25, 40, 60, 75, 80)

# Calculate Open-NL for Average (65 dB)
sii_65 <- sii(speech = 65, threshold = thresholds, freq = freqs, prescription = "Open-NL")

# Extract the calculated insertion gain targets
sii_65$gain
```

## VI. CONCLUSION

Open-NL provides a transparent, customizable computational framework for predicting WDRC insertion gain targets and benchmarking them against established industry standards natively within R. By coupling an explicitly defined mathematical pipeline with an embedded hybrid loudness model, the `SII` package allows audiologists and researchers to freely simulate and evaluate the theoretical intelligibility-loudness trade-off of various prescriptive heuristics without relying on opaque clinical fitting software. It is important to emphasize that Open-NL is purely a computational toolkit designed for theoretical modeling; it has not undergone behavioral validation and must not be used to fit hearing aids on human subjects.

## ACKNOWLEDGMENTS

During the preparation of this work, the author utilized a Large Language Model (LLM) assistant strictly for the purpose of language editing, structural formatting, and typesetting of the manuscript prose into JASA standards. After using this tool, the author reviewed and edited the content as needed and takes full and sole responsibility for the final content of the publication. The ANSI core engine of the `SII` package was originally developed by Gregory R. Warnes for the archived version of the package. Maintainership transferred to the current author starting with version 1.1.0, at which point all subsequent Open-NL prescriptive logic, clinical heuristics, and WDRC mathematical implementations were independently developed by the current author.

## AUTHOR DECLARATIONS

### Conflict of Interest

The author declares no conflicts of interest.

### Ethics Approval

The author declares that no animal subjects or human participants were involved in this research. Furthermore, no identifiable data are embedded in the interactive Shiny application or the code repository.

## DATA AVAILABILITY

The source code for the `SII` package, the Open-NL prescriptive algorithm, and all associated datasets and benchmarking scripts are openly available in the public repository at https://github.com/euphonic-euphemism/SII (v1.2.0; DOI: [DOI to be generated upon final repository release]; License: GPL-3.0).

## REFERENCES

Chang, Y. S., Park, H., Hong, S. H., et al. (2019). "Predicting Cochlear Dead Regions in Patients With Hearing Loss Through a Machine Learning-Based Approach: A Preliminary Study," PloS One.

Cox, R. M., Alexander, G. C., Johnson, J., & Rivera, I. (2011). "Cochlear Dead Regions in Typical Hearing Aid Candidates: Prevalence and Implications for Use of High-Frequency Speech Cues," Ear and Hearing.

Cox, R. M., Johnson, J. A., & Alexander, G. C. (2012). "Implications of High-Frequency Cochlear Dead Regions for Fitting Hearing Aids to Adults With Mild to Moderately Severe Hearing Loss," Ear and Hearing.

Narayanan, S. K., Rye, P., Houmøller, S. S., et al. (2024). "Difference in SII Provided by Initial Fit and NAL-NL2 and Its Relation to Self-Reported Hearing Aid Outcomes," International Journal of Audiology.

Berger, K. W., Hagberg, E. N., & Rane, R. L. (1980). "A Reexamination of the One-Half Gain Rule," Ear and Hearing.

Byrne, D., Dillon, H., Ching, T., Katsch, R., & Keidser, G. (2001). "NAL-NL1 Procedure for Fitting Nonlinear Hearing Aids: Characteristics and Comparisons With Other Procedures," Journal of the American Academy of Audiology.

Byrne, D., & Dillon, H. (1986). "The National Acoustic Laboratories' (NAL) new procedure for selecting the gain and frequency response of a hearing aid," Ear and Hearing.

Byrne, D., Parkinson, A., & Newall, P. (1990). "Hearing aid gain and frequency response requirements for the severely/profoundly hearing impaired," Ear and Hearing.

Chen, Z., Hu, G., Glasberg, B. R., & Moore, B. C. J. (2011). "A new model for calculating auditory excitation patterns and loudness for cases of cochlear hearing loss," The Journal of the Acoustical Society of America.

Ching, T. Y., Johnson, E. E., Hou, S., et al. (2013). "A Comparison of NAL and DSL Prescriptive Methods for Paediatric Hearing-Aid Fitting: Predicted Speech Intelligibility and Loudness," International Journal of Audiology.

Croteau, M., & Kwok, Y. (2026). "A comparison of compression thresholds and ratios in modern hearing aid prescriptions," Journal of the American Academy of Audiology.

Engler, M., Digeser, F., & Hoppe, U. (2026). "Speech Recognition and Real-Ear-Measured Amplification in Hearing-Aid Users With Various Grades of Hearing Loss," International Journal of Audiology.

Halpin, C., Thornton, A., & Hasso, M. (1994). "Low-Frequency Sensorineural Loss: Clinical Evaluation and Implications for Hearing Aid Fitting," Ear and Hearing.

Johnson, E. E. (2013). "An Initial-Fit Comparison of Two Generic Hearing Aid Prescriptive Methods (NAL-NL2 and CAM2) to Individuals Having Mild to Moderately Severe High-Frequency Hearing Loss," Journal of the American Academy of Audiology.

Johnson, E. E., & Dillon, H. (2011). "A Comparison of Gain for Adults From Generic Hearing Aid Prescriptive Methods: Impacts on Predicted Loudness, Frequency Bandwidth, and Speech Intelligibility," Journal of the American Academy of Audiology.

Keidser, G., Dillon, H., Carter, L., & O'Brien, A. (2012). "NAL-NL2 Empirical Adjustments," Trends in Amplification.

Keidser, G., Dillon, H., Flax, M., Ching, T., & Brewer, S. (2011). "The NAL-NL2 Prescription Procedure," Audiology Research.

Kitterick, P. T., Zakis, J. A., & Edwards, B. (2026). "Evolving the Philosophy: From the NAL Rule to NAL-NL3," International Journal of Audiology.

Kuk, F. K., Ludvigsen, C., & Paludan-Muller, C. (2003). "Improving hearing aid performance in hearing-impaired persons with reverse-slope sensorineural hearing loss," Journal of the American Academy of Audiology.

Leijon, A. (1991). "Hearing Aid Gain for Loudness-Density Normalization in Cochlear Hearing Losses With Impaired Frequency Resolution," Ear and Hearing.

Leijon, A., Lindkvist, A., Ringdahl, A., & Israelsson, B. (1991). "Sound Quality and Speech Reception for Prescribed Hearing Aid Frequency Responses," Ear and Hearing.

Lybarger, S. F. (1944). U.S. Patent Application SN 543,278.

Margolis, R. H., Hornsby, B. W. Y., Saly, G. L., & Wilson, R. H. (2025). "Predicted and Measured Word-Recognition Scores Unmask Distortion in the Impaired Auditory System," The Journal of the Acoustical Society of America.

McCreery, R. W., Crukley, J., Grindle, A., Merchant, G. R., & Walker, E. (2023a). "Predicting Children's Real-Ear-to-Coupler Differences Based on Tympanometric Data," International Journal of Audiology.

McCreery, R. W., Grindle, A., Merchant, G. R., Crukley, J., & Walker, E. A. (2023b). "Predicting Wideband Real-Ear-to-Coupler Differences in Children Using Wideband Acoustic Immittance," The Journal of the Acoustical Society of America.

Mueller, H. G. (2005). "Fitting Hearing Aids to Adults Using Prescriptive Methods: An Evidence-Based Review of Effectiveness," Journal of the American Academy of Audiology.

Pavlovic, C. V. (1987). "Derivation of primary parameters and procedures for use in speech intelligibility predictions," The Journal of the Acoustical Society of America.

Pepler, A., Munro, K. J., Lewis, K., & Kluk, K. (2014). "Prevalence of Cochlear Dead Regions in New Referrals and Existing Adult Hearing Aid Users," Ear and Hearing.

Pepler, A., Lewis, K., & Munro, K. J. (2015). "Adult Hearing-Aid Users With Cochlear Dead Regions Restricted to High Frequencies: Implications for Amplification," International Journal of Audiology.

Peters, R. W., Moore, B. C., Glasberg, B. R., & Stone, M. A. (2000). "Comparison of the NAL(R) and Cambridge Formulae for the Fitting of Linear Hearing Aids," British Journal of Audiology.

Plomp, R. (1978). "Auditory handicap of hearing impairment and the limited benefit of hearing aids," The Journal of the Acoustical Society of America.

Scollie, S. (2008). "Children's Speech Recognition Scores: The Speech Intelligibility Index and Proficiency Factors for Age and Hearing Level," Ear and Hearing.

Stelmachowicz, P. G., Lewis, D. E., Larson, L. L., & Jesteadt, W. (1985). "Upward spread of masking in normal-hearing and hearing-impaired listeners," The Journal of the Acoustical Society of America.

Storey, L., Dillon, H., Yeend, I., & Wigney, D. (1998). "The National Acoustic Laboratories' procedure for selecting the saturation sound pressure level of hearing aids: Experimental validation," Ear and Hearing.

Studebaker, G. A., & Sherbecoe, R. L. (1991). "Frequency-importance and transfer functions for recorded CID W-22 word lists," Journal of Speech and Hearing Research.

Valente, M., Oeding, K., Brockmeyer, A., Smith, S., & Kallogjeri, D. (2018). "Differences in Word and Phoneme Recognition in Quiet, Sentence Recognition in Noise, and Subjective Outcomes Between Manufacturer First-Fit and Hearing Aids Programmed to NAL-NL2 Using Real-Ear Measures," Journal of the American Academy of Audiology.

Van Tasell, D. J., & Turner, C. W. (1984). "Speech Recognition in a Special Case of Low-Frequency Hearing Loss," The Journal of the Acoustical Society of America.

Watts, K. M., Bagatto, M., Clark-Lewis, S., Henderson, S., Scollie, S., & Blumsack, J. (2020). "Relationship of Head Circumference and Age in the Prediction of the Real-Ear-to-Coupler Difference (RECD)," Journal of the American Academy of Audiology.

Windle, R., Dillon, H., & Heinrich, A. (2025). "Fast versus slow compression in hearing aids: A randomized controlled trial," Ear and Hearing.


## APPENDIX: EXPLORATORY MODULES

### A. Distortion-aware high-frequency penalty (untested heuristic)

A fundamental limitation of existing prescriptive algorithms is their reliance on the pure-tone audiogram, which ignores suprathreshold processing deficits inherent to outer/inner hair cell loss and synaptopathy (Plomp, 1978). Open-NL includes an explicitly untested heuristic designed to theoretically integrate the distortion categorization framework recently proposed by Margolis et al. (2025). The engine calculates a predicted Word Recognition Score (WRS) using the established CID W-22 transfer function (where the base is 10, valid for $0.0 \le \text{SII} \le 1.0$) (Studebaker & Sherbecoe, 1991):
\begin{equation}
\text{Predicted WRS (\%)} = 100 \cdot (1 - 10^{-(\text{SII} \cdot 3.28)})
\end{equation}
Per the Margolis et al. (2025) framework, the degree of cochlear distortion is categorized based on population distributions of measured-minus-predicted WRS differences, rather than a single-point comparison. It must be explicitly noted that SII-to-WRS transfer functions are known to be listener-, age-, and hearing-level-specific. Consequently, the adult-derived CID W-22 transfer function applied here is not portable to the pediatric use cases emphasized elsewhere in the Open-NL architecture. Open-NL then dynamically alters the prescription targets for highly distorted ears by applying high-frequency roll-offs (e.g., $-10$ dB/octave starting at 1500 Hz) and lowering the $L_{gain}$ soft-compression limit to prevent high-frequency saturation. This feature is intended solely as an exploratory research tool to bridge pure-tone algorithms with suprathreshold diagnostic data, and its perceptual effects require extensive behavioral validation.

### B. Exploratory reverse-slope suppression

For reverse-slope configurations (where the low-frequency thresholds are significantly worse than the high frequencies), an inverse logic may be appropriate to prevent upward spread of masking. Amplifying low frequencies aggressively in these cases degrades intelligibility because apical sensory units may be completely dysfunctional (Halpin et al., 1994), obscuring intact basal units that provide the bulk of speech information (Van Tasell & Turner, 1984). While these single-case and small-sample reports provide directional support (Kuk et al., 2003), implementing a specific algorithmic penalty remains an asserted heuristic. Because benchmark targets for mild reverse slopes (e.g., the A2 profile) do not demonstrate catastrophic recruitment even under unconstrained linear rationales (NAL-NL2 yields only 2.0 sones at 65 dB SPL), the necessity of this module is debated. Open-NL includes an optional suppression of the low-frequency correction array ($C_{interp}$) to a flat -10 dB floor for research purposes, employing a transitional factor ($RS_{factor}$) for signed slopes exceeding -15 dB:
\begin{equation}
\text{Slope}_{signed} = \text{PTA}_{HF} - \text{PTA}_{LF}
\end{equation}
\begin{equation}
RS_{factor} = \max\left(0, \min\left(1, \frac{-\text{Slope}_{signed} - 15}{20}\right)\right)
\end{equation}
\begin{equation}
C_{interp(LF)} = C_{interp(LF)} \cdot (1 - RS_{factor}) + (-10 \cdot RS_{factor})
\end{equation}
