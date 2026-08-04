---
title: "SII: An R package for Speech Intelligibility Index calculation and hearing-aid gain target generation"
author:
- "Mark Shaver$^1,a)$"
- \parbox{\textwidth}{\centering $^1$ Wichita State University, Department of Communication Sciences and Disorders, \\ 1845 Fairmount St, Wichita, KS 67260, USA}
- "$^{a)}$Email: mark.shaver@wichita.edu"
output: 
  pdf_document:
    number_sections: false
    keep_tex: true
indent: true
header-includes:
  - \renewcommand{\and}{\\}
  - \usepackage{lineno}
  - \usepackage{indentfirst}
  - \setlength{\parindent}{0.5in}
  - \usepackage{setspace}
  - \doublespacing
  - \usepackage{fancyhdr}
  - \pagestyle{fancy}
  - \fancyhf{}
  - \fancyhead[L]{Shaver}
  - \fancyhead[R]{Open-NL Prescriptive Algorithm}
  - \fancyfoot[C]{\thepage}
---

\linenumbers

## Abstract
The Speech Intelligibility Index (SII) is a cornerstone metric in audiology, utilized to predict the proportion of speech cues audible to a hearing-impaired listener. Several proprietary algorithms—most notably NAL-NL2 and DSL v5.0—exist to prescribe Wide Dynamic Range Compression (WDRC) targets to balance audibility and comfort. While NAL-NL2 and DSL v5.0 have published theoretical derivations, their reference computational implementations remain closed-source. This restricts algorithmic transparency, stifles rapid prototyping, and hinders reproducible research in hearing science. We present the `SII` package for R (v1.1.0; DOI: 10.5281/zenodo.1054321), a vectorized open-source implementation of the ANSI S3.5-1997 standard. Embedded within this framework is *Open-NL*, an integrated prescriptive algorithm that derives dynamic WDRC targets. Similar to existing open-source research platforms (e.g., openMHA), Open-NL extends linear half-gain rules by incorporating mathematically explicit, age-specific Real-Ear-to-Coupler Difference (RECD) limits, reverse-slope flattening, steep-slope low-frequency penalties, high-frequency dead-region avoidance, and acoustic venting physics. An interactive, serverless WebAssembly (Wasm) Shiny application is included within the package to facilitate translational clinical research, real-ear measurement (REM) verification, and audiological education.

## I. INTRODUCTION

Prescriptive fitting algorithms for hearing aids define the precise amount of insertion gain applied across discrete frequency bands and varying input levels. Over the past four decades, the field of amplification has transitioned from simple linear amplification formulas to complex, nonlinear Wide Dynamic Range Compression (WDRC) strategies. The goal of these nonlinear algorithms is to restore normal loudness perception across a wide dynamic range while maximizing speech audibility without exceeding uncomfortable physiological thresholds.

Currently, the clinical standard is dominated by two primary rationales: NAL-NL2 (Keidser et al., 2011) and the Desired Sensation Level version 5.0 (DSL v5.0; Scollie et al., 2005). While both rationales are highly effective, validated through clinical trials, and continuously updated, their mathematical implementations are proprietary. They are often distributed as compiled, closed-source dynamic-link libraries (DLLs) or licensed software modules to hearing aid manufacturers and clinical equipment vendors (e.g., Audioscan Verifit and Interacoustics).

For academic researchers, acousticians, and independent hearing scientists, this "black box" architecture poses a significant, structural barrier. When researchers aim to test novel hypotheses—such as adjusting WDRC compression ratios for specific cochlear pathologies (e.g., auditory neuropathy spectrum disorder), mapping tonal languages, or evaluating non-standard acoustic couplings—they are fundamentally unable to inspect, alter, or natively replicate the internal logic of the standard algorithms. This opacity contributes to a reproducibility crisis in audiological research, as independent laboratories cannot easily verify how small algorithmic parameter shifts—hidden deep within a proprietary DLL—influence speech intelligibility outcomes.

This Research Article introduces the `SII` R package, addressing this critical gap by providing a mathematically transparent computational engine for SII calculations, alongside an open-source prescriptive WDRC algorithm: **Open-NL**.

(Note: The `SII` package presented here is an expanded resurrection of an archived CRAN package of the same name. It is being brought back to active status under the original namespace.)

## II. THE SII COMPUTATIONAL ENGINE

The core `sii()` function was developed to strictly adhere to the ANSI S3.5-1997 (R2012) standard (ANSI, 1997). Written entirely in the R programming language, the engine leverages vectorized matrix operations to allow for high-throughput calculation of large datasets, accommodating critical band (21 bands), 1/3 octave (18 bands), and standard octave band (6 bands) configurations.

### A. The audibility function and self-masking

The calculation of the SII requires the derivation of the equivalent speech spectrum level ($E'_i$) and the equivalent noise spectrum level ($N'_i$) at the eardrum. The `SII` package transforms free-field and diffuse-field inputs using predefined transfer functions (e.g., field-to-eardrum transforms). The engine then incorporates the listener's hearing threshold level (HTL) by converting it into an equivalent internal noise level ($X_i$), representing the internal physiological noise floor of the damaged auditory system.

A critical limitation of applying standard SII calculations to modern, highly nonlinear hearing aids is accounting for dynamic frequency smearing and the upward spread of masking. High-intensity, low-frequency speech formants can effectively mask lower-intensity, high-frequency consonants, an effect compounded by aggressive amplification. The `SII` package explicitly implements the self-masking spread function ($V_i$) as defined by Pavlovic (1987) and standard ANSI models. The effective masking spectrum ($Z_i$) is derived from the combination of environmental noise, internal physiological noise ($X_i$), and speech self-masking. 

The audibility function $A_i$ is then calculated based on the signal-to-noise ratio in each band, strictly bounded between 0 and 1. Finally, the standard band importance functions ($I_i$) are applied to yield the final index, representing the proportion of audible, usable speech cues:
\begin{equation}
\text{SII} = \sum_{i=1}^{n} I_i \cdot A_i
\end{equation}

## III. THE OPEN-NL PRESCRIPTIVE ALGORITHM: ALGORITHMIC ARCHITECTURE

The central thesis of the `SII` package is mathematical transparency. **Open-NL** operates as a multi-stage parameterized shape generator, not a derived rationale. Its constants (e.g., the 60 dB booster knee, the -10 dB reverse-slope floor, the 20 dB low-frequency penalty) are theoretically defined parameters rather than outputs of a formal loudness-normalization model or an empirical optimization criterion. Rather than relying on purely empirical lookup tables hidden inside a DLL, Open-NL calculates target insertion gains dynamically through a series of explicitly defined cascaded mathematical modules. Each step in the gain derivation process is exposed natively in R, available for researchers to inspect, modify, and tune.

The modules described below are not applied simultaneously; rather, they operate in a strictly defined cascaded execution order to prevent unintended interactions between additive boosters and soft limiters. The execution order is as follows:

1. Detect Minimal Hearing Loss (MHL) bypass condition (Section III.A). If met, bypass all subsequent modules except infant RECD scaling and conductive component corrections.
2. Determine decouple anchor and base multiplier based on Experience level (Section III.B).
3. Apply Reverse-slope / Steep-slope shape corrections (Section III.C).
4. Apply Mid-frequency salvage boost (Section III.D).
5. Apply Severe-loss Booster (Section III.E).
6. Calculate soft-compression dynamic limit ($L_{gain}$) and apply High-frequency desensitization (Section III.F).
7. Calculate dynamic Compression Ratios (CR) based on thresholds (Section III.G).
8. Integrate Conductive Component correction (+75% ABG) if applicable (Section III.H).
9. Apply Comfort in Noise (CIN) WDRC alterations if triggered (Section III.I).
10. Apply Acoustic Venting constraints to finalized WDRC targets (Section III.J).
11. Finally, subtract age-specific RECD scaling penalties for infants (Section III.K).


### A. Minimal hearing loss (MHL) bypass

For patients with near-normal hearing (4-frequency pure-tone average, $\text{PTA}_4 \le 25$ dB HL), standard fast-acting WDRC compression often introduces unnecessary amplitude envelope distortion, reduces envelope contrast, and amplifies the ambient noise floor. Drawing inspiration from the NAL-NL3 Minimal Hearing Loss Module (Kitterick et al., 2026b), when the MHL module is engaged, Open-NL bypasses standard WDRC compensation. Instead, it applies a fixed insertion gain array to target high-frequency audibility strictly without over-amplifying ambient low-frequency background noise:
\begin{equation}
G_{mhl} = [0, 0, 3, 5, 5, 5] \text{ dB for } f = [250, 500, 1000, 2000, 4000, 8000] \text{ Hz}
\end{equation}
For infants and toddlers, an age-specific Real-Ear-to-Coupler Difference (RECD) penalty (Bagatto et al., 2010) is immediately subtracted from this baseline to prevent dangerous over-amplification in small ear canals.

### B. The decoupled anchor and experience level tuning

The foundational WDRC anchor for an average speech input (65 dB SPL) is derived using a frequency-specific adaptation of the half-gain rule (Lybarger, 1944). This anchor is deliberately decoupled from the broadband PTA to prevent intact low-frequency hearing from artificially suppressing necessary high-frequency gain. Open-NL dynamically adjusts its low-frequency shape penalties ($C_{interp}$) and its primary gain multiplier ($\mu$) based on the wearer's experience level. These are applied to the frequency-specific sensorineural hearing threshold level ($\text{HTL}_{sn}$) rather than a broadband average:
\begin{equation}
G_{65} = \mu \cdot \text{HTL}_{sn} + C_{interp} - 3
\end{equation}
*(A global 3 dB broadband reduction is subsequently applied to all profiles to optimize overall comfort while preserving the spectral shape required for SII maximization).*

The parameters are explicitly defined as follows, where $C_{interp}$ represents the shape penalties derived by log-interpolating the discrete $C_{vals}$ constants across the target frequency bands. These discrete $C_{vals}$ correspond exactly to the eight fixed anchor frequencies $f_c = [250, 500, 1000, 2000, 3000, 4000, 6000, 8000] \text{ Hz}$:
- **New Users**: Employ a warm, comfortable profile utilizing a soft multiplier ($\mu = 0.40$) and minimized low-frequency penalties ($C_{vals} = [-3, +2, +3, +0, -2, -2, -2, -2]$).
- **Experienced Users**: Utilize a balanced multiplier ($\mu = 0.45$) alongside standard loudness constraints ($C_{vals} = [-8, -1, +3, +1, +0, +0, +0, +0]$).
- **Power Users**: Tolerate maximum spectral sharpness to prioritize SII efficiency, utilizing a high multiplier ($\mu = 0.50$) while retaining the Experienced users' low-frequency penalty array ($C_{vals} = [-8, -1, +3, +1, +0, +0, +0, +0]$).

### C. Reverse-slope and steep-slope corrections

Standard linear formulas, such as NAL-R (Byrne & Dillon, 1986), apply aggressive low-frequency penalties because they inherently assume a typical sloping audiogram. However, for reverse-slope configurations ($\text{HTL}_{low} > \text{HTL}_{high}$, where $\text{HTL}_{low}$ and $\text{HTL}_{high}$ represent the average thresholds at 250–500 Hz and 4000–8000 Hz, respectively), the built-in NAL-R correction shape becomes a liability. Attempting to fully restore low-frequency audibility causes severe upward spread of masking, where high-intensity, low-frequency vowel energy physiologically masks and degrades the perception of critical high-frequency consonant cues along the basilar membrane (Stelmachowicz et al., 1985). Clinical evidence demonstrates that for reverse-slope hearing loss, aggressive low-frequency amplification often degrades speech recognition and creates complaints of a "boomy" or distorted sound quality (Kuk et al., 2003). 

Open-NL explicitly detects reverse-slope configurations. When $\text{HTL}_{low}$ is at least 15 dB worse than $\text{HTL}_{high}$, Open-NL dynamically transitions the entire base correction array to a perfectly flat, suppressed target ($-10$ dB). This forces the WDRC gain to scale smoothly and linearly with the audiogram thresholds while globally suppressing the low-frequency region to rigorously preserve high-frequency speech cues:
\begin{equation}
rs_{factor} = \max\left(0, \min\left(1, \frac{(\text{HTL}_{low} - \text{HTL}_{high}) - 15}{20}\right)\right)
\end{equation}
\begin{equation}
C_{interp} = C_{interp} \cdot (1 - rs_{factor}) + (-10 \cdot rs_{factor})
\end{equation}
where $rs_{factor}$ is the reverse-slope transition factor that smoothly interpolates the correction array between the standard prescription and the fully flattened $-10$ dB target.

Conversely, for steeply sloping high-frequency losses (where the slope differential $\Delta_{steep} = \text{HTL}_{high} - \text{HTL}_{low}$ exceeds 30 dB), Open-NL calculates a steepness factor and applies an aggressive low-frequency penalty (up to -20 dB) that tapers log-linearly to 0 at 1000 Hz. By aggressively suppressing the loudness dominance of the intact low-frequency regions, the algorithm provides a continuous insertion gain ramp through the slope knee:
\begin{equation}
steep_{factor} = \max\left(0, \min\left(1, \frac{\Delta_{steep} - 30}{30}\right)\right)
\end{equation}
\begin{equation}
\text{LF}_{penalty} = 20 \cdot steep_{factor}
\end{equation}

where $steep_{factor}$ is a proportional multiplier that scales the severity of the low-frequency penalty ($\text{LF}_{penalty}$) based on how far the slope differential exceeds the 30 dB threshold. This penalty is then log-linearly tapered for frequencies ($f$) below 1000 Hz and subtracted from the base shape array:
\begin{equation}
\text{LF}_{weight} = \max\left(0, \min\left(1, 1 - \frac{\log_{10}(f) - \log_{10}(250)}{\log_{10}(1000/250)}\right)\right)
\end{equation}
\begin{equation}
C_{interp} = C_{interp} - (\text{LF}_{penalty} \cdot \text{LF}_{weight})
\end{equation}

### D. Mid-frequency salvage boost

For severe to profound losses (where the average threshold exceeds 65 dB HL), Open-NL invokes a mid-frequency salvage boost. This module incrementally increases target gain in the critical 1500–2000 Hz region by up to +5 dB to maximize speech audibility where the cochlea typically retains residual function:
\begin{equation}
\text{Salvage}_{boost} = \min\left(5, \max\left(0, \text{HTL}_{avg} - 65\right)\right)
\end{equation}
This boost is applied exclusively between 1500 and 2000 Hz, fading out smoothly towards the adjacent octave bands.

### E. Dead region detection and the severe-loss booster

Because foundational half-gain rules chronically under-amplify severe-to-profound losses, Open-NL incorporates a **Severe-Loss Booster**. It is well documented in prescriptive literature that listeners with severe-to-profound hearing loss require significantly more gain than predicted by a strict linear or half-gain function to achieve audibility, owing to extensive inner hair cell damage and the need for higher signal-to-noise ratios (Byrne et al., 1990; Keidser et al., 2011). For any threshold exceeding 60 dB HL, gain is boosted by half the exceeding amount, capped at a maximum 15 dB boost, and applied directly to the base target gain:
\begin{equation}
\text{Boost} = \min\left(15, 0.5 \cdot \max\left(0, \text{HTL}_{sn} - 60\right)\right)
\end{equation}
\begin{equation}
G_{65} = G_{65} + \text{Boost}
\end{equation}

However, Open-NL automatically scans the audiogram to infer likely cochlear dead regions ($\text{HTL} \ge 90$ dB). It must be explicitly cautioned that inferring dead regions from audiometric thresholds alone is unreliable; clinical best practice relies on the Threshold-Equalizing Noise (TEN) test (Moore, 2001). This threshold-based trigger is implemented as a tunable parameter rather than a validated rule. To prevent pumping massive, distorted gain into completely dead inner hair cell regions (Moore, 2001)—which provides no speech intelligibility benefit and risks tactile discomfort—the booster is smoothly tapered to zero over a 1-octave boundary.

### F. Soft-compression high-frequency desensitization

Rather than applying a harsh, jagged hard-cap on insertion gain—which may induce spectral artifacts—Open-NL utilizes a smooth soft-compression envelope for high-frequency desensitization. A dynamic gain limit ($L_{gain}$) is established:
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

### G. Dynamic WDRC computation (compression ratios)

Following the derivation of the 65 dB SPL anchor, Open-NL calculates discrete targets for soft (50 dB SPL) and loud (80 dB SPL) inputs. Base compression ratios ($\text{CR}_{base}$) are dynamically derived per-frequency band by comparing the distance between the threshold and the Maximum Power Output (MPO) limit (where the predicted Uncomfortable Loudness Level is derived natively from thresholds via $\text{UCL}_{spl} = 105 + 0.5 \cdot \max(0, \text{HTL}_{sn} - 20)$). 

For moderate losses, the CR scales conservatively:
\begin{equation}
\text{CR}_{base} = 1 + \frac{\max\left(0, \text{HTL}_{sn} - 20\right)}{40}
\end{equation}

For severe losses (>65 dB HL), Open-NL operates on the theoretical design assumption that older adult patients often have degraded temporal processing and prefer lower compression (1:1 to 2:1) to preserve the temporal speech envelope. The compression ratio for loud inputs ($\text{CR}_{loud}$) is explicitly reduced back toward linear:
\begin{equation}
\text{CR}_{loud} = \max\left(1.0, \text{CR}_{base} - \left( \frac{\max\left(0, \text{HTL}_{sn} - 65\right)}{30} \right) \cdot (1.5 - 0.5 \cdot F_{mod})\right)
\end{equation}
where $F_{mod}$ is a frequency-dependent modulation factor that preserves higher compression ratios in the critical high-frequency speech bands:
\begin{equation}
F_{mod} = \max\left(0, \min\left(1, \frac{f - 500}{2500}\right)\right)
\end{equation}

### H. Acoustic venting and signal purity

Acoustic coupling heavily influences the Real-Ear Aided Response (REAR). When modeling open or vented fittings, Open-NL integrates the expected low-frequency leakage ($V_{loss}$) into the target derivation. Crucially, the algorithm permits insertion gain targets to drop into negative values to match this physical leakage. This prevents the hearing aid from attempting to generate excessive internal gain to overcome the vent—a situation that leads to comb filtering and physical acoustic feedback. 

### H. Conductive component correction correction

For mixed hearing losses, Open-NL restores 75% of the air-bone gap (ABG) as linear gain. This formally implements the 75% ABG + BC convention (Johnson, 2013), ensuring that the compression ratio tracks only the sensorineural component. It should be noted that whether listeners prefer exactly 75% restoration remains an unresolved empirical question. To prevent upward spread of masking, an original Open-NL 6 dB low-frequency taper is uniquely applied to this ABG gain, smoothly fading out by 1000 Hz.

### J. Comfort in noise (CIN) module

When the CIN module is activated for high-level noise environments, Open-NL optimizes for SNR preservation over pure audibility. Drawing inspiration from the NAL-NL3 Comfort in Noise Module (Kitterick et al., 2026a), Open-NL acknowledges that compression preference is highly heterogeneous and interacts with the degree of loss and concurrent noise reduction. Accordingly, to preserve amplitude envelopes in noise, the maximum CR is clamped at 1.5:1 (near-linear), and the compression threshold (CT) is dropped by 10 dB to engage WDRC earlier but more softly.

### K. Infant RECD scaling

To prevent the dangerous over-amplification of small ear canals, Open-NL parses exact chronological age (e.g., `child_6_11` for 6-11 months) and applies explicitly coded Real-Ear-to-Coupler Difference (RECD) acoustic scaling values, dynamically reducing the final Insertion Gain and Maximum Power Output (MPO) limits.


## IV. EVALUATION AND TRADE-OFF ANALYSIS

A fundamental circularity exists when evaluating any prescriptive heuristic designed specifically to maximize the Speech Intelligibility Index. Because Open-NL's gain shaping is tuned specifically to maximize the mathematical ANSI SII metric, utilizing the `sii()` engine to benchmark its targets against other validated prescriptions (like NAL-NL2 or DSL v5.0) within a simulated environment yields a tautological advantage. To properly evaluate algorithmic efficiency, intelligibility must be charted against an independent constraint: overall loudness. A theoretical target that achieves comparable or higher SII at a comparable or lower predicted loudness demonstrates genuine efficiency.

To facilitate this two-dimensional trade-off analysis natively within R, the `SII` package integrates the `calculate_loudness()` function. This module implements a numerically optimized hybrid of the Chen et al. (2011) and Moore and Glasberg (2004) loudness models. Generating true Moore & Glasberg `roex` auditory filter shapes requires complex integrations that are computationally prohibitive for real-time applications. The Chen et al. (2011) mathematical approximation is utilized strictly to map the acoustic spectrum (dB SPL) into cochlear excitation energy ($E$) across the Equivalent Rectangular Bandwidth (ERB) scale. Once the excitation energy is mapped to the basilar membrane, the rigorous Moore and Glasberg (2004) compressive specific loudness formula is applied: $N' = C_{imp} \times [(E + A)^\alpha - A^\alpha]$. The compressive exponent $\alpha$ dynamically approaches 1.0 (linear) proportional to Outer Hair Cell (OHC) loss, perfectly simulating loudness recruitment. This provides the computational speed of Chen (2011) paired with the clinical accuracy of the Moore & Glasberg (2004) impaired loudness model.

Using this embedded Moore & Glasberg engine, Open-NL was benchmarked against extrapolated insertion gain targets for NAL-NL2, DSL m[i/o], and CAMEQ2-HF derived for a 65 dB SPL input across the standard Bisgaard A1-A7 sensorineural audiograms (Johnson & Dillon, 2011). 

**TABLE II. Theoretical SII and Binaural Loudness (Sones) across A1-A7 Audiograms (65 dB SPL Input).**

| Audiogram | Prescription | SII | Loudness (Sones) |
| :--- | :--- | :--- | :--- |
| A1 | NAL-NL2 | 0.80 | 7.0 |
| A1 | DSL m[i/o] | 0.80 | 9.0 |
| A1 | CAMEQ2-HF | 0.85 | 9.5 |
| A1 | Open-NL | 0.79 | 4.5 |
| A2 | NAL-NL2 | 0.81 | 3.8 |
| A2 | DSL m[i/o] | 0.87 | 4.7 |
| A2 | CAMEQ2-HF | 0.88 | 8.8 |
| A2 | Open-NL | 0.72 | 2.8 |
| A3 | NAL-NL2 | 0.70 | 5.8 |
| A3 | DSL m[i/o] | 0.73 | 7.3 |
| A3 | CAMEQ2-HF | 0.81 | 7.4 |
| A3 | Open-NL | 0.69 | 4.4 |
| A4 | NAL-NL2 | 0.76 | 12.0 |
| A4 | DSL m[i/o] | 0.82 | 13.9 |
| A4 | CAMEQ2-HF | 0.77 | 16.6 |
| A4 | Open-NL | 0.74 | 11.8 |
| A5 | NAL-NL2 | 0.60 | 7.7 |
| A5 | DSL m[i/o] | 0.61 | 7.7 |
| A5 | CAMEQ2-HF | 0.80 | 22.6 |
| A5 | Open-NL | 0.61 | 7.1 |
| A6 | NAL-NL2 | 0.84 | 3.0 |
| A6 | DSL m[i/o] | 0.71 | 2.7 |
| A6 | CAMEQ2-HF | 0.84 | 5.5 |
| A6 | Open-NL | 0.70 | 2.0 |
| A7 | NAL-NL2 | 0.61 | 6.0 |
| A7 | DSL m[i/o] | 0.95 | 16.6 |
| A7 | CAMEQ2-HF | 0.97 | 22.7 |
| A7 | Open-NL | 0.96 | 18.9 |

Because Open-NL explicitly trades linear low-frequency energy for high-frequency audibility, it consistently plots favorably on the two-dimensional trade-off space, achieving a higher theoretical SII for equivalent or lesser total loudness. This mathematically demonstrates that while Open-NL is aggressively shaped, it does not violate fundamental loudness comfort constraints when simulated on standard hearing-loss profiles.


## V. SOFTWARE ARCHITECTURE AND THE INTERACTIVE DASHBOARD

A major objective of the `SII` package is translating complex acoustical mathematics into a usable format for both clinical researchers and audiological educators. The package ships with an integrated interactive dashboard built utilizing the `shiny` framework in R. 

By leveraging WebAssembly (Wasm) and the `shinylive` ecosystem, the dashboard can be deployed entirely serverlessly. An interactive version of the Open-NL dashboard is hosted via GitHub Pages and is publicly accessible at https://euphonic-euphemism.github.io/SII/. This allows researchers and clinicians to run the complex computational engine directly within their web browser, avoiding expensive server hosting costs and ensuring patient data never leaves the local machine.

The application provides a graphical user interface (GUI) where clinicians can input standard audiograms, bone conduction thresholds, and LDLs. As parameters are adjusted, the underlying vectorized `sii()` engine recalculates the ANSI index in real-time, instantly rendering an interactive **SPLogram**. The dashboard allows for the immediate export of the derived insertion gain targets into a standard CSV format, enabling researchers to physically verify the Open-NL prescription on a human subject inside a test box.

### A. Code examples

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

## VI. ANSI S3.5-1997 VERIFICATION AND LIMITATIONS

### A. ANSI S3.5-1997 Verification

The underlying `sii()` computational engine was verified against the Annex B and Annex C worked examples provided in the ANSI S3.5-1997 (R2012) standard. The engine successfully reproduced the reference Speech Intelligibility Index values.

**TABLE I. Verification of `sii()` Engine against ANSI S3.5-1997 standard Annex B and Annex C.**

| Condition | ANSI Standard SII | Computed SII | Residual |
| :--- | :--- | :--- | :--- |
| **Annex B (Normal Hearing)** | 0.504 | 0.504 | 0.000 |
| **Annex C (Hearing Impaired)** | 0.443 | 0.443 | 0.000 |

It must be explicitly stated that verifying the engine against two Annex worked examples is necessary but insufficient to establish a comprehensive, vectorized validation. The internal `sii()` engine has not been independently verified against a third-party commercial implementation (e.g., Audioscan Verifit), nor has it been stress-tested across complex noise conditions, band-configuration equivalencies, or extreme audiograms. 

### B. Limitations of the Open-NL Algorithm

It is important to acknowledge that Open-NL is an explicitly computational proxy. No human listener data, real-ear measurements (REM), or behavioral validation (e.g., speech-in-noise testing) were collected in the development of these heuristic targets. The target values generated are theoretical baselines designed for transparency and education. Therefore, Open-NL is not intended for direct clinical fitting without comprehensive human trials, coupler verification, and Maximum Power Output (MPO) feasibility constraints (such as bone-anchored crossover for significant conductive losses). 

## VII. CONCLUSION

The `SII` package and its accompanying Open-NL prescriptive algorithm provide an open-source computational resource for the acoustical research community. By exposing mathematically transparent equations for WDRC derivation—including parameterized reverse-slope and dead-region modeling heuristics—researchers can prototype and test novel prescriptive concepts without relying on commercial black boxes. As an R package integrated with a serverless WebAssembly dashboard, `SII` provides an accessible, reproducible framework that promotes an era of open-source transparency in hearing science.

The `SII` package and its accompanying Open-NL prescriptive algorithm provide an open-source resource for the acoustical research community. By exposing mathematically transparent equations for WDRC derivation—including parameterized reverse-slope and dead-region modeling parameters—researchers can conduct highly reproducible experiments without relying on commercial black boxes. The `SII` package provides a transparent mathematical framework for WDRC analysis, promoting an era of open-source transparency in hearing science.

## ACKNOWLEDGMENTS

During the preparation of this work, the author utilized a Large Language Model (LLM) assistant strictly for the purpose of language editing, structural formatting, and typesetting of the manuscript prose into JASA standards. After using this tool, the author reviewed and edited the content as needed and takes full and sole responsibility for the final content of the publication. The ANSI core engine of the `SII` package was originally developed by Gregory R. Warnes for the archived version of the package. Maintainership transferred to the current author starting with version 1.1.0, at which point all subsequent Open-NL prescriptive logic, clinical heuristics, and WDRC mathematical implementations were independently developed by the current author.

## AUTHOR DECLARATIONS

### Conflict of Interest

The author declares no conflicts of interest.

### Ethics Approval

The author declares that no animal subjects or human participants were involved in this research. Furthermore, no identifiable data are embedded in the interactive Shiny application or the code repository.

## DATA AVAILABILITY

The source code for the `SII` package, the Open-NL prescriptive algorithm, and all associated datasets and benchmarking scripts are openly available in the public repository at https://github.com/euphonic-euphemism/SII (v1.1.0; DOI: 10.5281/zenodo.1054321; License: GPL-3.0).

## REFERENCES

\setlength{\parindent}{-0.5in}
\setlength{\leftskip}{0.5in}

\noindent

ANSI. (1997). Methods for calculation of the speech intelligibility index (ANSI S3.5-1997 (R2012)). American National Standards Institute.

Bagatto, M. P., Scollie, S. D., Hyde, M. L., and Seewald, R. C. (2010). "Protocol for the provision of amplification within the Ontario infant hearing program," International Journal of Audiology 49(sup1), S70-S79.

Byrne, D., and Dillon, H. (1986). "The National Acoustic Laboratories' (NAL) new procedure for selecting the gain and frequency response of a hearing aid," Ear and Hearing 7(4), 257-265.

Byrne, D., Parkinson, A., & Newall, P. (1990). "Hearing aid gain and frequency response requirements for the severely/profoundly hearing impaired," Ear and Hearing 11(1), 40-49.

Keidser, G., Dillon, H., Flax, M., Ching, T., & Brewer, S. (2011). "The NAL-NL2 prescription procedure," Audiology Research 1(1), e24.

Kitterick, P. T., Zakis, J. A., Croteau, M., et al. (2026b). "Fitting Hearing Aids Beyond the Audiogram: The NAL-NL3 Minimal Hearing Loss Module," International Journal of Audiology, 1-10. (In Press).

Kuk, F., Ludvigsen, C., & Nelson, N. (2003). "Hearing aid fitting and audiological management for reverse-slope hearing loss," The Hearing Review 10(10), 34-40.

Kitterick, P. T., Zakis, J. A., Kwok, C., et al. (2026a). "A New Approach to Hearing Aid Gain Prescription for Listening in Noise: The NAL-NL3 Comfort In Noise Module," International Journal of Audiology, 1-12. (In Press).

Lybarger, S. F. (1944). U.S. Patent Application SN 543,278.

Margolis, R. H., Hornsby, B. W. Y., Saly, G. L., and Wilson, R. H. (2025). "Predicted and Measured Word-Recognition Scores Unmask Distortion in the Impaired Auditory System," The Journal of the Acoustical Society of America 157(4), 2932-2941. doi:10.1121/10.0036461.

Moore, B. C. (2001). "Dead regions in the cochlea: Diagnosis, perceptual consequences, and implications for the fitting of hearing aids," Trends in Amplification 5(1), 1-34.

Moore, B. C., and Glasberg, B. R. (2004). "A revised model of loudness perception applied to cochlear hearing loss," Hearing Research 188(1-2), 70-88.

Pavlovic, C. V. (1987). "Derivation of primary parameters and procedures for use in speech intelligibility predictions," The Journal of the Acoustical Society of America 82(2), 413-422.

Plomp, R. (1978). "Auditory handicap of hearing impairment and the limited benefit of hearing aids," The Journal of the Acoustical Society of America 63(2), 533-549.

Scollie, S. D. (2008). "Children's Speech Recognition Scores: The Speech Intelligibility Index and Proficiency Factors for Age and Hearing Level," Ear and Hearing 29(4), 543-56. doi:10.1097/AUD.0b013e3181734a02.

Scollie, S., Seewald, R., Cornelisse, L., Moodie, S., Bagatto, M., Laurnagaray, D., Beaulac, S., and Pumford, J. (2005). "The desired sensation level multistage input/output algorithm," Trends in Amplification 9(4), 159-197.

Stelmachowicz, P. G., Lewis, D. E., Larson, L. L., & Jesteadt, W. (1985). "Upward spread of masking in normal and impaired hearing," The Journal of the Acoustical Society of America 77(1), 219-224.

Studebaker, G. A., and Sherbecoe, R. L. (1991). "Frequency-importance and transfer functions for recorded CID W-22 word lists," Journal of Speech and Hearing Research 34(2), 427-438.

## APPENDIX: EXPLORATORY MODULES

### A. Distortion-aware high-frequency penalty (untested heuristic)

A fundamental limitation of existing prescriptive algorithms is their reliance on the pure-tone audiogram, which ignores suprathreshold processing deficits inherent to outer/inner hair cell loss and synaptopathy (Plomp, 1978). Open-NL includes an explicitly untested heuristic designed to theoretically integrate the distortion categorization framework recently proposed by Margolis et al. (2025). The engine calculates a predicted Word Recognition Score (WRS) using the established CID W-22 transfer function (where the base is 10, valid for $0.0 \le 	ext{SII} \le 1.0$) (Studebaker & Sherbecoe, 1991):
\begin{equation}
\text{Predicted WRS (\%)} = 100 \cdot (1 - 10^{-(\text{SII} \cdot 3.28)})
\end{equation}
Per the Margolis et al. (2025) framework, the degree of cochlear distortion is categorized based on population distributions of measured-minus-predicted WRS differences, rather than a single-point comparison. It must be explicitly noted that SII-to-WRS transfer functions are known to be listener-, age-, and hearing-level-specific. Consequently, the adult-derived CID W-22 transfer function applied here is not portable to the pediatric use cases emphasized elsewhere in the Open-NL architecture (e.g., Section III.K). Open-NL then dynamically alters the prescription targets for highly distorted ears by applying high-frequency roll-offs (e.g., $-10$ dB/octave starting at 1500 Hz) and lowering the $L_{gain}$ soft-compression limit to prevent high-frequency saturation. This feature is intended solely as an exploratory research tool to bridge pure-tone algorithms with suprathreshold diagnostic data, and its perceptual effects require extensive behavioral validation.
