# The Open-NL Dynamic Compression Algorithm

## Overview
Because standard clinical targets (such as NAL-NL2 and DSL v5.0a) are proprietary and require commercial licensing for their source code, the `SII` package introduces **Open-NL**, a completely transparent, open-source proxy algorithm. It mimics the sophisticated, multi-stage Wide Dynamic Range Compression (WDRC) behaviors of modern clinical prescriptions. 

By keeping Open-NL fully open-source, researchers, students, and developers can inspect, modify, and distribute its core logic without restrictive licensing.

## Mathematical Implementation

Open-NL computes frequency-specific insertion gain through a series of explicit mathematical stages based on the patient's audiogram, demographic factors, and acoustic coupling.

### 1. Base Linear Anchor
Open-NL uses a half-gain rule that is decoupled from the broadband Pure Tone Average (PTA). This prevents normal low-frequency hearing from artificially dragging down high-frequency gain.
It starts with a frequency-specific constant array (`c_vals`), similar to the original NAL-R, but modified to provide a warmer tonal balance (less low-frequency penalty, higher compression in the highs). A global **-3 dB broadband loudness penalty** is then applied to the entire array to optimize loudness comfort (bringing the overall gain closer to NAL-NL2 and DSL targets) while preserving the frequency shape required to maximize the Speech Intelligibility Index (SII). 
The exact array scales dynamically based on the patient's `experience` level:
- **New Users:** Very warm, comfortable profile (less low-frequency penalty, more high-frequency compression).
- **Experienced Users:** Balanced profile optimized for SII and comfortable loudness.
- **Power Users:** Maximum sharpness and high-frequency gain.

### 2. Audiometric Corrections


#### Steep Slope / Dead Region Penalty
For steeply sloping losses (e.g., normal hearing up to 1000 Hz, dropping sharply to 80 dB HL at 2000 Hz), over-amplifying the steep region causes severe upward spread of masking and distortion. 
Open-NL identifies the "knee" (the frequency at which the slope becomes steep) and applies a gradual penalty (up to -6 dB) around the knee to prevent masking, while simultaneously applying a high-frequency boost (up to +6 dB) to pull the higher frequencies out of the slope to maximize SII.

### 3. Pediatric and Age Modifications (RECD)
Standard prescriptions assume an adult ear canal. Open-NL automatically calculates Real-Ear-to-Coupler Difference (RECD) corrections for children:
- If `age < 5`, low-frequency targets are boosted, and compression ratios are softened (linearized) to maximize speech audibility for language acquisition.
- If `age_years > 60`, the maximum compression ratio (CR) is gently reduced to prevent cognitive overload and temporal distortion in older adults.

### 4. Dynamic Compression (WDRC)
Unlike static NAL-R, Open-NL computes an Input/Output (I/O) curve:
1. **Compression Threshold (CT):** Set 5 dB above the normal speech spectrum for each frequency band.
2. **Compression Ratios (CR):** Calculated based on the degree of hearing loss (half-gain rule).
3. **Gain Calculation:** 
   - For input levels $\le$ CT, the hearing aid acts linearly (applying the `g_ct` gain).
   - For input levels $>$ CT, the gain is compressed dynamically using the formula:
     $Gain = g_{ct} - (Input - CT) \times (1 - 1/CR)$

### 5. Acoustic Coupling and Leakage
Depending on the earmold vent or dome, low-frequency amplified sound escapes out of the ear canal. Open-NL uses acoustic leakage vectors to model this vent effect, converting the theoretical insertion gain into the Real-Ear Aided Response (REAR).
- **Generic Domes (Balling et al., 2019):** Empirically derived leakage values for Open Dome (massive low-frequency leakage, up to -35 dB), Tulip Dome, and Double Dome (up to -20 dB).
- **Custom Vents (Kuk et al., 2009):** Empirical leakage values for explicit vent sizes (1 mm, 2 mm, 3 mm). We distinguish between **Solid Molds** (long vent length, higher acoustic mass) and **Hollow Molds** (short vent length, lower acoustic mass). A shorter vent provides less resistance to escaping sound, causing substantially more low-frequency gain to leak out compared to a solid mold of the exact same diameter. For example, a 1 mm hollow vent has the same massive leakage (-12 dB at 250 Hz) as a 3 mm solid vent!

### 6. SSPL90 / MPO Clipping
Finally, Open-NL calculates the patient's Loudness Discomfort Level (LDL). If the user does not provide `ldl` values, it estimates them based on the hearing thresholds (using the Pascoe/Dillon estimation). 
The final prescribed output (Input + Gain) is strictly clipped at the MPO (Maximum Power Output) to ensure the hearing aid never exceeds the uncomfortable loudness level.
