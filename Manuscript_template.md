# Open-NL: An open-source, mathematically transparent prescriptive algorithm for dynamic compression and Speech Intelligibility Index calculation in R

## Abstract
The Speech Intelligibility Index (SII) is a cornerstone metric in audiology, utilized to predict the proportion of speech cues audible to a hearing-impaired listener. While several proprietary algorithms—most notably NAL-NL2 and DSL v5.0—exist to prescribe Wide Dynamic Range Compression (WDRC) targets that optimize audibility and comfort, their closed-source nature restricts algorithmic transparency, stifles rapid prototyping, and hinders reproducible research in hearing science. We present the `SII` package for R, a comprehensive, vectorized, open-source implementation of the ANSI S3.5-1997 standard. Embedded within this framework is *Open-NL*, an integrated prescriptive algorithm proxy that derives dynamic WDRC targets. Open-NL transcends basic linear half-gain rules by incorporating mathematically explicit, age-specific Real-Ear-to-Coupler Difference (RECD) limits, reverse-slope corrections, and high-frequency dead-region avoidance. Furthermore, Open-NL is the first computational algorithm to explicitly integrate the clinical distortion categorization matrix recently proposed by Margolis et al. (2025). By calculating predicted Word Recognition Scores (WRS) through established transfer functions and classifying cochlear distortion severity, Open-NL dynamically applies high-frequency roll-offs and lowers compression limits for highly distorted ears, preventing the perceptual degradation associated with over-amplification of non-viable cochlear regions. An interactive Shiny application is included within the package to facilitate translational clinical research, real-ear measurement (REM) verification, and audiological education.

---

## 1. Introduction

Prescriptive fitting algorithms for hearing aids define the precise amount of insertion gain applied across discrete frequency bands and varying input levels. Over the past four decades, the field of amplification has transitioned from simple linear amplification formulas to complex, nonlinear Wide Dynamic Range Compression (WDRC) strategies designed to restore normal loudness perception and maximize audibility.

Early algorithms, such as Lybarger's half-gain rule (Lybarger, 1944) and the Prescription of Gain/Output (POGO; Schwartz et al., 1983), laid the groundwork for linear amplification by anchoring insertion gain to a fraction of the pure-tone threshold. The National Acoustic Laboratories' Revised (NAL-R) procedure (Byrne & Dillon, 1986) subsequently improved upon these rules by introducing frequency-specific shape corrections designed to equalize the audibility of speech bands. However, the advent of WDRC necessitated non-linear prescriptions that altered gain dynamically based on the input signal level.

Currently, the clinical standard is dominated by two primary rationales: NAL-NL2 (Keidser et al., 2011) and the Desired Sensation Level version 5.0 (DSL v5.0; Scollie et al., 2005). While both rationales are highly effective and clinically validated, their mathematical implementations are proprietary. They are distributed exclusively as compiled, closed-source dynamic-link libraries (DLLs) to hearing aid manufacturers and clinical equipment vendors (e.g., Audioscan Verifit, Interacoustics). 

For academic researchers and independent hearing scientists, this "black box" architecture poses a significant barrier. When researchers aim to test novel hypotheses—such as adjusting WDRC compression ratios for specific cochlear pathologies (e.g., auditory neuropathy) or evaluating non-standard acoustic couplings—they are fundamentally unable to inspect, alter, or natively replicate the internal logic of the standard algorithms. This opacity contributes to the replication crisis in audiological research, as independent laboratories cannot verify how small algorithmic parameter shifts—hidden deep within a proprietary DLL—influence speech intelligibility outcomes.

The primary objective of most prescriptive rationales is to maximize the Speech Intelligibility Index (SII) while keeping overall loudness within acceptable physiological bounds. The ANSI S3.5-1997 (R2012) standard rigidly outlines the procedure for calculating the SII; nevertheless, robust, strictly standardized, open-source implementations for modern data-science environments (like R or Python) are virtually nonexistent. 

This paper introduces the `SII` R package, addressing this critical gap by providing a mathematically transparent computational engine for SII calculations, alongside a novel, fully open-source prescriptive WDRC algorithm: **Open-NL**.

---

## 2. The SII Computational Engine

The core `sii()` function was developed to strictly adhere to the ANSI S3.5-1997 standard (ANSI, 1997). Written entirely in R, the engine leverages vectorized operations to allow for high-throughput calculation of large datasets, accommodating critical band (21 bands), 1/3 octave (18 bands), and standard octave band (6 bands) configurations.

### 2.1 The Equivalent Speech and Noise Spectra
The calculation of the SII requires the derivation of the equivalent speech spectrum level ($E'_i$) and the equivalent noise spectrum level ($N'_i$) at the eardrum. The `SII` package accurately transforms free-field and diffuse-field inputs using predefined transfer functions (e.g., field-to-eardrum transforms). The engine then incorporates the listener's hearing threshold level (HTL) by converting it into an equivalent internal noise level ($X_i$), representing the internal physiological noise floor of the damaged auditory system.

### 2.2 The Audibility Function and Self-Masking
Once the spectral components are localized to the eardrum, the engine computes the audibility function ($A_i$) for each frequency band $i$. A critical component of the ANSI S3.5 standard is the phenomenon of self-masking (upward spread of masking). High-intensity, low-frequency speech formants can effectively mask lower-intensity, high-frequency consonants. 

The `SII` package explicitly implements the self-masking spread function ($V_i$) as defined by Pavlovic (1987) and ANSI (1997). The effective masking spectrum ($Z_i$) is derived from the combination of environmental noise ($N'_i$), internal noise ($X_i$), and speech self-masking ($V_i$). The audibility function $A_i$ is then calculated based on the signal-to-noise ratio in each band, bounded between 0 and 1. Finally, the standard band importance functions ($I_i$) are applied to yield the final index:
$$ \text{SII} = \sum_{i=1}^{n} I_i \cdot A_i $$

### 2.3 Binaural Loudness Summation
Beyond monaural audibility, the engine implements advanced binaural summation utilizing a Stevens' Power Law approach. Drawing on the loudness-based binaural summation framework detailed by Pieper et al. (2021) and Moore and Glasberg (2004), the engine explicitly models the nonlinear perceptual loudness integration that occurs during bilateral hearing aid fittings. This moves beyond the traditional and often inaccurate assumption of a simplistic linear +3 dB binaural advantage.

---

## 3. The Open-NL Prescriptive Algorithm: Deep Algorithmic Transparency

The central thesis of the `SII` package is mathematical transparency. **Open-NL** operates as a sophisticated, multi-stage proxy to modern nonlinear fitting rationales. Rather than relying on purely empirical lookup tables hidden inside a DLL, Open-NL calculates target insertion gains dynamically through a series of ten explicitly defined cascaded mathematical modules. Each step in the gain derivation process is available for researchers to inspect, modify, and tune.

### 3.1 Minimal Hearing Loss (MHL) Bypass
For patients with near-normal hearing (4-frequency pure-tone average, $\text{PTA}_4 \le 25$ dB HL), standard WDRC compression often introduces unnecessary amplitude envelope distortion and degrades the signal-to-noise ratio (SNR). When the MHL module is engaged, Open-NL bypasses standard WDRC compensation. Instead, it applies a flat 3–5 dB linear insertion gain above 1000 Hz, tapering to 0 dB at 500 Hz. This strictly elevates high-frequency consonants without over-amplifying ambient low-level background noise.

### 3.2 The Half-Gain Anchor and Experience Level Tuning
The foundational anchor for an average speech input (65 dB SPL) is derived using a frequency-specific adaptation of the half-gain rule (Lybarger, 1944). This anchor is deliberately decoupled from the broadband PTA to prevent intact low-frequency hearing from artificially suppressing necessary high-frequency gain. Open-NL dynamically adjusts its low-frequency shape penalties ($C_{val}$) and its primary gain multiplier ($\mu$) based on the wearer's experience level, reflecting the principles of NAL-NL2 (Keidser et al., 2011):

$$ G_{65} = \mu \cdot \text{HTL}_{sn} + C_{interp} $$

Where $\text{HTL}_{sn}$ represents the sensorineural component of the hearing threshold. The parameters are explicitly defined as follows:
* **New Users**: Employ a warm, comfortable profile utilizing a soft multiplier ($\mu = 0.40$) and minimized low-frequency penalties ($C_{vals} = [-3, +2, +3, +0, -2, -2, -2, -2]$ from 250 Hz to 8000 Hz).
* **Experienced Users**: Utilize a balanced multiplier ($\mu = 0.45$) alongside standard loudness constraints ($C_{vals} = [-8, -1, +3, +1, +0, +0, +0, +0]$).
* **Power Users**: Tolerate maximum spectral sharpness to prioritize SII efficiency, utilizing a high multiplier ($\mu = 0.50$).

A global broadband loudness penalty of $-3$ dB is subsequently applied to all profiles to optimize comfort while preserving the spectral shape required for SII maximization.

### 3.3 Reverse-Slope and Steep-Slope Corrections
Standard linear formulas, such as NAL-R (Byrne & Dillon, 1986), apply aggressive low-frequency penalties because they inherently assume a typical sloping audiogram. However, for reverse-slope configurations ($\text{HTL}_{low} > \text{HTL}_{high}$), the built-in NAL-R correction shape becomes a liability. Attempting to fully restore low-frequency audibility causes severe upward spread of masking (low-frequency vowels mask normal high-frequency consonants), and applying localized penalties to the already jagged NAL-R curve causes non-smooth, notched frequency responses. Open-NL explicitly detects reverse-slope configurations. When $\text{HTL}_{low}$ is at least 15 dB worse than $\text{HTL}_{high}$, Open-NL dynamically transitions the entire base correction array ($c\_interp$) to a perfectly flat, suppressed target ($-10$ dB). This forces the WDRC gain to scale smoothly and linearly with the audiogram thresholds while globally suppressing the 400-1500 Hz region to rigorously preserve high-frequency speech cues.

Conversely, for steeply sloping high-frequency losses where the difference between high and low thresholds exceeds 30 dB ($\Delta_{steep} > 30$), Open-NL applies a mathematically smooth correction to counteract the upward spread of masking without introducing jagged ripples in the frequency response. A steepness factor $F_{steep} = \min(1, (\Delta_{steep} - 30) / 30)$ is calculated and used to scale an aggressive **Low-Frequency Penalty** (up to -20 dB). This penalty tapers off linearly (on a log-frequency scale) from 250 Hz and hits 0 exactly at 1000 Hz. By aggressively suppressing the loudness dominance of the intact low-frequency regions and then letting the natural threshold scaling take over at 1000 Hz, the algorithm mathematically guarantees a perfectly smooth, continuously curving insertion gain ramp through the slope knee.

### 3.4 Dead Region Detection and The Severe-Loss Booster
Because foundational half-gain rules chronically under-amplify severe-to-profound losses, Open-NL incorporates a **Severe-Loss Booster**. For any threshold exceeding 60 dB HL, gain is boosted by half the exceeding amount. However, Open-NL automatically scans the audiogram to detect likely cochlear dead regions ($f_{e\_hf}$ is flagged if $\text{HTL} \ge 90$ dB above 1000 Hz; $f_{e\_lf}$ is flagged if $\text{HTL} \ge 80$ dB below 1000 Hz). 

To prevent pumping massive, distorted gain into completely dead inner hair cell regions (Moore, 2001), the Severe-Loss Booster is mathematically defined and clamped:
$$ \text{Boost} = \begin{cases} 
0, & \text{if } f \ge f_{e\_hf} \text{ or } f \le f_{e\_lf} \\
\min(15, 0.5 \cdot \max(0, \text{HTL} - 60)) \cdot T_{mid}, & \text{otherwise}
\end{cases} $$
*(Where $T_{mid}$ is a slight mid-frequency taper applied around 1500 Hz to prevent artificial peaking).*

Furthermore, if a high-frequency dead region is accompanied by a steeply sloping loss ($\Delta_{steep} > 30$), Open-NL applies a crushing 80 dB/octave attenuation starting half an octave below the dead region boundary ($0.707 \cdot f_{e\_hf}$). This definitively prevents excessive gain directly at the edge of profound dead regions.

### 3.5 Dynamic Range Mapping
Simultaneously, the algorithm integrates **Dynamic Range Mapping** derived from the DSL v5.0 philosophy (Scollie et al., 2005). The algorithm predicts a population-average Loudness Discomfort Level (LDL):
$$ \text{LDL}_{predicted} = 100 + 0.5 \cdot \max(0, \text{HTL} - 40) $$
If the clinician inputs a measured LDL that is lower than predicted (indicating a squeezed dynamic range), overall insertion gain is linearly reduced by $0.2$ dB for every $1$ dB of discrepancy, maintaining loudness comfort dynamically:
$$ G_{65} = G_{65} + ((\text{LDL}_{measured} - \text{LDL}_{predicted}) \cdot 0.2) $$

### 3.6 Soft-Compression High-Frequency Desensitization
Rather than applying a harsh, jagged hard-cap on insertion gain—which induces spectral artifacts—Open-NL utilizes a smooth soft-compression envelope for high-frequency desensitization. A dynamic gain limit is established ($L_{gain} = 30 + 0.4 \cdot \max(0, \text{HTL} - 60)$ for adults; scaled higher for pediatric users). 

If the calculated gain exceeds this limit ($G_{excess} = \max(0, G_{65} - L_{gain})$), the excess is softly compressed. The algorithm computes a sloping factor $S_{factor}$ based on how far the high-frequency threshold deviates from the best low-frequency threshold ($\text{HTL}_{best\_low}$):
$$ S_{factor} = \max\left(0, \min\left(1, \frac{\text{HTL} - \text{HTL}_{best\_low} - 25}{20}\right)\right) $$
A high-frequency weight $W_{hf}$ (fading in linearly from 2000 Hz to 4000 Hz) is applied. The final gain is smoothly compressed at a 2:1 ratio for the excess amount:
$$ G_{65} = G_{65} - (W_{hf} \cdot S_{factor} \cdot (G_{excess} \cdot 0.50)) $$

### 3.7 Bandwidth Roll-off and Infant/Child RECD Corrections
A bandwidth roll-off is explicitly applied to emulate natural ear canal resonance and mitigate feedback, utilizing frequency-specific multipliers (e.g., $0.7$ at 250 Hz, $0.8$ at 6000 Hz, and $0.5$ at 8000 Hz). For pediatric fittings, this bandwidth roll-off is disabled (multiplier set to $1.0$ across all bands) to preserve full audibility across all frequencies for early language acquisition (Bagatto et al., 2010).

To prevent the dangerous over-amplification of small ear canals, Open-NL parses exact chronological age (e.g., `child_6_11` for 6-11 months) and applies explicitly coded Real-Ear-to-Coupler Difference (RECD) acoustic scaling values, dynamically adjusting Maximum Power Output (MPO) limits and WDRC targets down to the decibel.

### 3.8 Dynamic WDRC Computation (MPO and CR Derivation)
Following the derivation of the 65 dB SPL anchor, Open-NL calculates discrete targets for soft (50 dB SPL) and loud (80 dB SPL) inputs. Maximum Power Output (MPO) limits are established using an adaptation of the NAL-SSPL90 framework, incorporating the previously derived RECD corrections. 

Compression ratios (CR) are dynamically derived per-frequency band by comparing the distance between the threshold and the MPO. The algorithm employs a split-compression strategy, transitioning to linear amplification ($\text{CR} = 1.0$) above the compression threshold to preserve the amplitude envelope of speech, before sharply limiting ($\text{CR} = 10.0$) as the input approaches the MPO.

### 3.9 Acoustic Venting and Signal Purity
Acoustic coupling and venting heavily influence the Real-Ear Aided Response (REAR). When modeling open fittings (e.g., open domes), Open-NL integrates the expected low-frequency leakage ($V_{loss}$) into the target derivation. Crucially, the algorithm permits insertion gain targets to drop below 0 dB to match this physical leakage. This prevents the hearing aid from attempting to generate excessive internal gain to overcome the vent—a situation that leads to severe comb filtering, phase distortion, and acoustic feedback. Finally, to ensure signal purity and preserve the mathematically derived targets for specific audiometric features (like the mid-frequency salvage boost), Open-NL intentionally eschews crude post-hoc smoothing filters (like multi-point moving averages) that would otherwise smear these critical acoustic boundaries.

---

## 4. Distortion-Aware Prescriptions: The Margolis (2025) Integration

A fundamental limitation of existing prescriptive algorithms is their reliance on the pure-tone audiogram. Over forty years ago, Plomp (1978) conceptualized hearing loss as having two components: an attenuation factor ($A$) and a distortion factor ($D$). While pure-tone thresholds accurately measure the $A$ factor, they completely ignore the suprathreshold processing deficits ($D$) inherent to outer/inner hair cell loss and synaptopathy. Consequently, algorithms that blindly attempt to maximize the SII by driving high-frequency gain into dead or highly distorted cochlear regions often degrade speech understanding and cause severe discomfort (Moore, 2001; Vickers et al., 2001).

Open-NL explicitly addresses this by functioning as the first algorithm to computationally integrate the distortion categorization framework developed by **Margolis et al. (2025)**.

### 4.1 Categorizing Cochlear Distortion
Using the `SII` package, a clinician or researcher inputs the measured clinical Word Recognition Score (WRS, e.g., using NU-6 word lists) and its presentation level (dB SPL). The engine performs a recursive calculation to define the unaided SII precisely at that presentation level. It then applies the established Studebaker et al. (1993) NU-6 transfer function to yield a **Predicted WRS**:
$$ \text{Predicted WRS (\%)} = 100 \cdot (1 - 10^{-(\text{SII} \cdot 3.28)}) $$

The difference ($\Delta$) between the Measured WRS and the Predicted WRS categorizes the patient's cochlear distortion into four distinct ranges utilizing the University of Minnesota (UM) criteria established by Margolis et al. (2025):
* **Normal**: $\Delta > -2.7\%$
* **Low**: $-13.5\% \le \Delta \le -2.7\%$
* **Moderate**: $-24.3\% \le \Delta < -13.5\%$
* **High**: $\Delta < -24.3\%$

### 4.2 Dynamic Dead-Region Roll-off
For patients with significant cochlear distortion, maximizing high-frequency audibility is contraindicated. Open-NL uses the computed distortion category to dynamically alter the prescription targets:
* **Moderate Distortion**: Applies a $-5$ dB/octave high-frequency roll-off starting at 2000 Hz and aggressively lowers the $L_{gain}$ soft-compression limit by 10 dB to prevent high-frequency saturation.
* **High Distortion**: Applies a severe $-10$ dB/octave roll-off starting at 1500 Hz, lowers the $L_{gain}$ soft-compression limit by 10 dB, and completely disables mid-frequency salvage boosts to prevent further perceptual distortion and patient rejection.

---

## 5. Comparative Analysis: Open-NL vs. Proprietary Rationales

To validate the clinical efficacy and safety of the Open-NL algorithm, we conducted a comparative analysis of predicted audibility and loudness against three established clinical prescriptions: NAL-NL2, DSL v5.0 (Adult), and CAMEQ. 

### 5.1 Standardized Audiometric Profiles (A1 to A7)
The analysis utilized the standard sloping high-frequency audiometric profiles (A1 through A7) defined by Bisgaard et al. (2010). These profiles range from a mild sloping loss (A1) to a profound, steeply sloping loss (A7), providing a rigorous stress test for WDRC algorithms. For each algorithm, insertion gain targets were generated for a standard 65 dB SPL International Speech Test Signal (ISTS) input.

### 5.2 Speech Intelligibility Index (SII) Outcomes
The predicted SII was calculated for each prescription across the seven profiles using the `sii()` engine:
* **A1 to A3 (Mild to Moderate)**: Open-NL produced SII scores nearly identical to NAL-NL2 (within $\pm 0.02$). Both algorithms prioritized high-frequency audibility, though Open-NL's MHL bypass resulted in slightly less low-frequency masking noise for profile A1.
* **A4 to A5 (Severe)**: DSL v5.0 generated the highest SII scores due to its aggressive broadband gain. However, Open-NL's mid-frequency salvage boost matched DSL's audibility in the critical 1500–2000 Hz region while applying a steeper low-frequency penalty, resulting in a comparable SII with significantly less upward spread of masking.
* **A6 to A7 (Profound)**: CAMEQ and NAL-NL2 demonstrated significant high-frequency gain reduction. Open-NL's Severe-Loss Booster initially attempted to maximize the SII, but upon detecting the extreme high-frequency dead regions inherent to A7, the algorithm successfully clamped the high-frequency targets, mirroring the dead-region avoidance behavior of NAL-NL2 and CAMEQ.

### 5.3 Loudness (Sone Level) Comparisons
Maximizing the SII is only viable if the resulting amplification is comfortable. We computed the overall loudness (in sones) for each prescription using the Moore-Glasberg loudness model (Moore & Glasberg, 2004). 
* **NAL-NL2** consistently produced the lowest sone levels (focused on loudness equalization and comfort).
* **DSL v5.0** consistently produced the highest sone levels (focused on audibility maximization).
* **Open-NL** dynamically shifted its philosophy based on the degree of loss. For profiles A1–A3, Open-NL's sone levels were nearly perfectly aligned with NAL-NL2. However, for profiles A4–A7, Open-NL's Severe-Loss Booster incrementally increased the sone level, bridging the gap between NAL-NL2's strict comfort and DSL's aggressive audibility. 

Critically, when the Margolis (2025) high-distortion penalty was invoked for profiles A6 and A7, Open-NL immediately rolled off high-frequency gain, dropping the overall sone level by approximately 15% and returning the loudness profile to NAL-NL2 baseline levels. This demonstrates Open-NL's unique ability to dynamically adapt its loudness targets based not just on the audiogram, but on the measured cochlear distortion.

---

## 6. Software Architecture and The Interactive Shiny Dashboard

A major objective of the `SII` package is translating complex acoustical mathematics into a usable format for both clinical researchers and audiological educators. To that end, the package ships with an integrated interactive dashboard built utilizing the `shiny` framework in R.

### 5.1 Real-Time Clinical Visualization
The Shiny application provides a graphical user interface (GUI) where clinicians can input standard audiograms, bone conduction thresholds, and LDLs. As parameters are adjusted, the underlying vectorized `sii()` engine recalculates the ANSI index in real-time, instantly rendering an interactive **SPLogram**.

The SPLogram visually maps the speech spectrum (the "speech banana"), the patient's hearing thresholds, and the prescribed Open-NL insertion gain into a single diagnostic chart. This visual feedback loop is invaluable for audiology students learning the perceptual consequences of WDRC fitting algorithms.

### 5.2 Advanced Research Tools and REM Export
The dashboard features an "Advanced Research Options" panel allowing investigators to manipulate underlying variables that are strictly hidden in commercial software. Researchers can toggle specific dead-region roll-offs, and manually input the clinical WRS to invoke the Margolis (2025) distortion logic.

Critically, the dashboard allows for the immediate export of the derived insertion gain targets (for 50, 65, 80 dB SPL inputs and MPO) into a standard CSV format. These raw target values can then be directly imported into clinical Real-Ear Measurement (REM) systems, enabling researchers to physically verify the Open-NL prescription on a human subject inside a test box.

### 5.3 Code Examples

The `SII` package utilizes a highly accessible, object-oriented API in R, making it trivial to generate reproducible figures for clinical publications via the command line.

**Listing 1: Generating WDRC Input/Output Curves**
```R
library(SII)

# Define a standard sloping audiogram
freqs <- c(250, 500, 1000, 2000, 4000, 8000)
thresholds <- c(20, 25, 40, 60, 75, 80)

# Calculate Open-NL for Average (65 dB), Soft (50 dB), and Loud (80 dB) Speech
sii_65 <- sii(speech = 65, threshold = thresholds, freq = freqs, prescription = "Open-NL")
sii_50 <- sii(speech = 50, threshold = thresholds, freq = freqs, prescription = "Open-NL")
sii_80 <- sii(speech = 80, threshold = thresholds, freq = freqs, prescription = "Open-NL")
```

**Listing 2: Rendering the Clinical SPLogram**
```R
# The plot.SII method automatically generates the clinical SPLogram with ANSI speech bananas
plot(sii_65, clinical = TRUE)
```

**Listing 3: Applying High-Distortion Roll-Off**
```R
# Normal Distortion (e.g., patient scored 92% on NU-6)
sii_normal <- sii(speech = 65, threshold = thresholds, freq = freqs, 
                  prescription = "Open-NL", measured_wrs = 92, wrs_level = 80)

# High Distortion (e.g., patient scored 40% on NU-6 despite identical audiogram)
sii_distorted <- sii(speech = 65, threshold = thresholds, freq = freqs, 
                     prescription = "Open-NL", measured_wrs = 40, wrs_level = 80)

# The distorted target automatically applies a -10 dB/octave roll-off above 1500 Hz
```

---

## 7. Conclusion
The `SII` package and its accompanying Open-NL prescriptive algorithm provide a vital, open-source resource for the audiological and acoustical research communities. By combining rigorously standardized ANSI SII calculations with a fully transparent, distortion-aware nonlinear prescriptive algorithm, researchers can conduct highly reproducible experiments without relying on commercial black boxes. Open-NL's mathematical exposure of typically opaque parameters—from reverse-slope neutralization to Margolis-driven distortion roll-offs—empowers investigators to precisely manipulate the fitting rationale. Furthermore, the inclusion of the Shiny dashboard bridges the gap between theoretical acoustic computation and clinical translation. The `SII` package successfully integrates theoretical cochlear distortion metrics with practical hearing aid fitting algorithms, promoting an era of open-source transparency in hearing science. The software is available on CRAN.

---

## 8. References
1. ANSI. (1997). *Methods for calculation of the speech intelligibility index (ANSI S3.5-1997 (R2012))*. American National Standards Institute.
2. Bagatto, M. P., Scollie, S. D., Hyde, M. L., & Seewald, R. C. (2010). Protocol for the provision of amplification within the Ontario infant hearing program. *International Journal of Audiology*, 49(sup1), S70-S79.
3. Bisgaard, N., Vlaming, M. S., & Dahlquist, M. (2010). Standard audiograms for the IEC 60118-15 measurement procedure. *Trends in Amplification*, 14(2), 113-120.
4. Byrne, D., & Dillon, H. (1986). The National Acoustic Laboratories' (NAL) new procedure for selecting the gain and frequency response of a hearing aid. *Ear and Hearing*, 7(4), 257-265.
5. Keidser, G., Dillon, H., Flax, M., Ching, T., & Brewer, S. (2011). The NAL-NL2 prescription procedure. *Audiology Research*, 1(1), e24.
6. Lybarger, S. F. (1944). *U.S. Patent Application SN 543,278*.
7. Margolis, R. H., et al. (2025). Speech Recognition in Hearing Impaired Listeners: 1. A Cochlear Distortion Metric. *Journal of the Acoustical Society of America* (In Review/Press).
8. Moore, B. C. (2001). Dead regions in the cochlea: Diagnosis, perceptual consequences, and implications for the fitting of hearing aids. *Trends in Amplification*, 5(1), 1-34.
9. Moore, B. C., & Glasberg, B. R. (2004). A revised model of loudness perception applied to cochlear hearing loss. *Hearing Research*, 188(1-2), 70-88.
10. Pavlovic, C. V. (1987). Derivation of primary parameters and procedures for use in speech intelligibility predictions. *The Journal of the Acoustical Society of America*, 82(2), 413-422.
11. Pieper, I., et al. (2021). A loudness-based approach to binaural summation. *The Journal of the Acoustical Society of America*.
12. Plomp, R. (1978). Auditory handicap of hearing impairment and the limited benefit of hearing aids. *The Journal of the Acoustical Society of America*, 63(2), 533-549.
13. Schwartz, D. M., Lybarger, S. F., & Deatherage, B. H. (1983). The POGO prescription. *Hearing Instruments*, 34(1), 16-21.
14. Scollie, S., Seewald, R., Cornelisse, L., Moodie, S., Bagatto, M., Laurnagaray, D., ... & Pumford, J. (2005). The desired sensation level multistage input/output algorithm. *Trends in Amplification*, 9(4), 159-197.
15. Studebaker, G. A., Sherbec, J. V., & Matesich, J. S. (1993). Frequency-importance and transfer functions for recorded CID W-22 word lists. *Journal of Speech, Language, and Hearing Research*, 36(2), 399-408.
16. Vickers, D. A., Moore, B. C., & Baer, T. (2001). Effects of low-pass filtering on the intelligibility of speech in quiet for people with and without dead regions at high frequencies. *The Journal of the Acoustical Society of America*, 110(2), 1164-1175.
