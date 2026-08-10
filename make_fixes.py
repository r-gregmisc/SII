import re

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "r") as f:
    text = f.read()

# 1. Section III Contradiction
old_tautology = """A fundamental circularity exists when evaluating any prescriptive heuristic designed specifically to maximize the Speech Intelligibility Index. Because Open-NL's gain shaping is tuned specifically to maximize the mathematical ANSI SII metric, utilizing the `sii()` engine to benchmark its targets against other validated prescriptions (like NAL-NL2 or DSL v5.0) within a simulated environment yields a tautological advantage. To properly evaluate algorithmic efficiency, intelligibility must be charted against an independent constraint: overall loudness. A theoretical target that achieves comparable or higher SII at a comparable or lower predicted loudness demonstrates genuine efficiency."""

new_tautology = """Because Open-NL contains no formal optimization step and relies on cascaded mathematical heuristics, it carries no tautological advantage when evaluated for the Speech Intelligibility Index (SII) within a simulated environment. Consequently, overall loudness is the most informative independent axis for evaluating its intelligibility. To properly evaluate algorithmic efficiency, intelligibility must be charted against this independent constraint: a theoretical target that achieves comparable or higher SII at a comparable or lower predicted loudness demonstrates genuine efficiency."""

text = text.replace(old_tautology, new_tautology)


# 2. Table I Arithmetic & Summary
old_summary = "Open-NL occupies the low-loudness region of the trade-off space. It tracks NAL-NL2 in predicted audibility in A1, A3, A4, and A5 (within 0.01–0.02 SII) while predicting fewer total sones. It underperforms NAL-NL2 in A2 and A6. Overall, the NAL-NL2 and DSL benchmarks average 6.4 and 7.3 sones across the five sensorineural configurations, correctly validating the physiological scale of the impaired loudness module compared to the normal-hearing standard (18.6 sones for 65 dB SPL ILTASS)."

new_summary = "Open-NL occupies the low-loudness region of the trade-off space. It tracks NAL-NL2 in predicted audibility in A1, A3, A4, and A5 (within 0.05, 0.08, 0.04, and 0.07 SII respectively) while predicting fewer total sones. Overall, the NAL-NL2 and DSL benchmarks average 8.68 and 9.92 sones across the five sensorineural configurations. This correctly validates the physiological scale of the impaired loudness module: Johnson & Dillon (2011) reported approximately 8 sones for both NAL-NL2 and DSL m[i/o] across these exact profiles compared to the 18.6-sone normal-hearing reference."

text = text.replace(old_summary, new_summary)


# 3. Restore Safety Content & Caveats
# A) MPO-Domain Saturation Limit
mpo_text = """### J. MPO-domain saturation limit

To prevent runaway loudness recruitment—particularly when Severe-Loss Boosters interact with profound cochlear damage or uncapped conductive air-bone gaps—Open-NL implements an explicit MPO-domain saturation ceiling. Rather than constraining average-speech inputs, the algorithm evaluates a 90 dB SPL input (SSPL90) to cap the maximum output (Dillon & Storey, 1998; Storey et al., 1998). Open-NL mathematically guarantees that the projected SSPL90 output never exceeds the patient's predicted Loudness Discomfort Levels (LDL) across any frequency band.

"""
text = text.replace("### J. Comfort in noise (CIN)", mpo_text + "### K. Comfort in noise (CIN)")
text = text.replace("### K. Acoustic venting", "### L. Acoustic venting")
text = text.replace("### L. Infant RECD scaling", "### M. Infant RECD scaling")


# B) ABG Caps
old_conductive = """The resulting gain addition must be linear because conductive blocks attenuate sound before it reaches the nonlinear cochlear amplifier. Thus, adding $0.75 \cdot \text{ABG}$ identically to $G_{50}$, $G_{65}$, and $G_{80}$ accurately preserves the compression ratios generated for the sensorineural component alone. The Open-NL logic mirrors established heuristics for mixed loss, applying this offset broadly across all functional frequencies."""

new_conductive = """The resulting gain addition must be linear because conductive blocks attenuate sound before it reaches the nonlinear cochlear amplifier. Thus, adding $0.75 \cdot \text{ABG}$ identically to $G_{50}$, $G_{65}$, and $G_{80}$ accurately preserves the compression ratios generated for the sensorineural component alone. However, because these additions are applied linearly, massive, uncapped ABG restorations risk generating output SPLs capable of permanently damaging the remaining sensorineural capacity. To enforce safety, Open-NL strictly caps the ABG restoration at 30 dB and enforces a global ceiling where total insertion gain cannot exceed 85% of the total threshold. To prevent upward spread of masking, an original Open-NL 6 dB low-frequency taper is uniquely applied to this ABG gain, smoothly fading out by 1000 Hz. This aligns with threshold-shift risk modeling which estimates that prescriptive gains become unsafe above 90 dB HL (NAL-NL2) or 80 dB HL (DSL m[i/o]) (Narayanan et al., 2024)."""
text = text.replace(old_conductive, new_conductive)


# C) Infant RECD Caveat
old_recd = """For infants under 36 months, Open-NL dynamically subtracts age-specific RECD values (McCreery et al., 2023a; McCreery et al., 2023b; Watts et al., 2020) to prevent dangerous over-amplification in small ear canals. The subtraction scales exponentially, heavily penalizing high frequencies in the youngest cohorts."""

new_recd = """For infants under 36 months, Open-NL dynamically subtracts age-specific RECD values (McCreery et al., 2023a; McCreery et al., 2023b; Watts et al., 2020) to prevent dangerous over-amplification in small ear canals. The subtraction scales exponentially, heavily penalizing high frequencies in the youngest cohorts. However, age-based RECD prediction carries an accuracy of only ~54% to 62% within $\pm$ 3 dB compared to measured values (McCreery et al., 2023a). Consequently, this computational module does not substitute for real-ear verification. Where age is unavailable, Open-NL provides fallbacks utilizing wideband acoustic immittance or head circumference predictions if supplied by the researcher."""
text = text.replace(old_recd, new_recd)


# D) Loudness Engine Limitations & Digitization Sensitivity
# We replace the clinical accuracy sentence and insert the sensitivity caveat.
text = text.replace("This provides the computational speed of Chen (2011) paired with the clinical accuracy of the Moore & Glasberg (2004) impaired loudness model.", 
"This provides the computational speed of Chen (2011) paired with the impaired loudness logic of Moore & Glasberg (2004). However, the hybrid engine remains unverified against reference implementations in impaired conditions, and evaluating loudness strictly at 65 dB SPL cannot fully characterize a nonlinear WDRC system.")

# E) Digitization Sensitivity before Table I
old_comparator = "Comparator targets for these profiles were digitized directly from the published 1/3-octave figures in Johnson and Dillon (2011)."
new_comparator = "Comparator targets for these profiles were digitized directly from the published 1/3-octave figures in Johnson and Dillon (2011). It must be noted that this digitization extraction process carries a $\pm$ 3-5 dB margin of error which can produce $\pm$ 0.12 SII swings in simulation; consequently, essentially all between-formula differences listed below are uninterpretable as strict clinical findings."
text = text.replace(old_comparator, new_comparator)
# Also remove the redundancy from the A5 prose:
text = text.replace("While the model reports higher intelligibility for Open-NL (SII = 0.67 vs 0.60), the digitization of the comparator targets carries a $\pm$ 3-5 dB margin of error. Given this digitization error inherent in extracting the comparator targets, which can produce $\pm$ 0.12 SII swings, essentially all between-formula differences are uninterpretable as strict clinical findings; therefore, the A5 result supports only a claim of comparability, not strict superiority.", "While the model reports higher intelligibility for Open-NL (SII = 0.67 vs 0.60), the A5 result supports only a claim of comparability, not strict superiority, given the error margins inherent in the digitized comparators.")


# F) Execution List numbering
old_exec_list = """The modules described below are not applied simultaneously; rather, they operate in a strictly defined cascaded execution order to prevent unintended interactions between additive boosters and soft limiters. The execution order is as follows:

1. Detect Minimal Hearing Loss (MHL) bypass condition (Section II.A). If met, bypass all subsequent modules except infant RECD scaling and conductive component corrections.
2. Generate baseline Half-Gain anchor (Section II.B).
3. Apply Slope-Dependent Low-Frequency Penalty (SD-LFP) for recruitment mitigation (Section II.C).
4. Apply Mid-frequency salvage boost (Section II.E).
5. Apply Severe-loss high-frequency boost (Section II.F).
6. Apply Dead Region tapering (Section II.F).
7. Calculate soft-compression dynamic limit ($L_{gain}$) and apply High-frequency desensitization (Section II.G).
8. Calculate dynamic Compression Ratios (CR) based on thresholds (Section II.H).
9. Integrate Conductive Component correction (+75% ABG) if applicable (Section II.I).
10. Apply Comfort in Noise (CIN) WDRC alterations if triggered (Section II.J).
11. Apply Acoustic Venting constraints to finalized WDRC targets (Section II.K).
12. Finally, subtract age-specific RECD scaling penalties for infants (Section II.L)."""

new_exec_list = """The modules described below are not applied simultaneously; rather, they operate in a strictly defined cascaded execution order to prevent unintended interactions between additive boosters and soft limiters. The execution order is as follows:

1. Detect Minimal Hearing Loss (MHL) bypass condition (Section II.A). If met, bypass all subsequent modules.
2. Generate baseline Half-Gain anchor (Section II.B).
3. Apply Slope-Dependent Low-Frequency Penalty (SD-LFP) for recruitment mitigation (Section II.C).
4. Apply Mid-frequency salvage boost (Section II.E).
5. Apply Severe-loss high-frequency boost and Dead Region tapering (Section II.F).
6. Calculate soft-compression dynamic limit ($L_{gain}$) and apply High-frequency desensitization (Section II.G).
7. Calculate dynamic Compression Ratios (CR) based on thresholds (Section II.H).
8. Integrate Conductive Component correction (+75% ABG) with a 30 dB cap and global ceiling (Section II.I).
9. Apply MPO-domain saturation limit to ensure output safety (Section II.J).
10. Apply Comfort in Noise (CIN) WDRC alterations if triggered (Section II.K).
11. Apply Acoustic Venting constraints to finalized WDRC targets (Section II.L).
12. Finally, subtract age-specific RECD scaling penalties for infants (Section II.M)."""
text = text.replace(old_exec_list, new_exec_list)


# 4. Dead-Region Evidence Reversal
old_dead = """### F. Dead region detection and the severe-loss booster

For profound hearing loss, Open-NL automatically scans the audiogram to infer likely cochlear dead regions (HTL $\ge 90$ dB) before applying its severe-loss booster (Byrne et al., 1990). If a dead region is inferred in the high frequencies, the algorithm tapers the booster above the critical frequency, acknowledging that amplification in such regions often introduces distortion rather than useful speech cues. To complement this, Open-NL restricts high-frequency boosting by applying a discrete cap:
\begin{equation}
\text{Boost} = \min(15, 0.5 \cdot \max(0, \text{HTL} - 60))
\end{equation}
This cap is explicitly applied to $G_{65}$ prior to compression ratio calculation, serving as a blunt limitation against driving dead regions into painful saturation."""

new_dead = """### F. Dead region detection and the severe-loss booster

Open-NL explicitly leaves dead-region gain reductions disabled by default. While profound hearing loss implies severe Outer Hair Cell (OHC) damage, evidence indicates that pure-tone thresholds and audiometric slopes cannot reliably identify cochlear dead regions (Cox et al., 2011; Chang et al., 2019). Furthermore, in adults with mild-to-moderately-severe loss, providing full high-frequency gain has not been shown to produce poorer performance, making threshold-inferred tapering a priori indefensible (Cox et al., 2012; Pepler et al., 2014; Pepler et al., 2015).

Instead, Open-NL provides a severe-loss booster aligned with the Byrne et al. (1990) finding that half-gain logic ceases to be optimal above $\sim 70$ dB HL, requiring up to 10 dB of additional insertion gain for severe-to-profound configurations. Open-NL achieves this by scaling the anchor (Equation 2) directly, without requiring an additive Equation 10 boost:
\begin{equation}
G_{anchor} = \min(0.46 \cdot \text{HTL}, 0.46 \cdot \text{HTL} + \min(10, 0.15 \cdot \max(0, \text{HTL} - 70)))
\end{equation}
This explicitly bounds the severe-loss boost to 10 dB, maintaining physiological safety without relying on inaccurate dead-region inference."""
text = text.replace(old_dead, new_dead)


# 5. Equation Resolving & L_gain (Double Boost)
# First we need to replace the old Eq 2 since we integrated it above.
old_eq2_context = """Thus, Open-NL fixes the linear anchor at 0.46:
\begin{equation}
G_{anchor} = 0.46 \cdot \text{HTL} + 0.15 \cdot \max(0, \text{HTL} - 60)
\end{equation}"""
new_eq2_context = """Thus, Open-NL fixes the linear anchor at 0.46, with the severe-loss boost appended directly into the anchor for extreme thresholds (as detailed in Section II.F):
\begin{equation}
G_{anchor} = \min(0.46 \cdot \text{HTL}, 0.46 \cdot \text{HTL} + \min(10, 0.15 \cdot \max(0, \text{HTL} - 70)))
\end{equation}"""
text = text.replace(old_eq2_context, new_eq2_context)

# Restore L_gain
old_lgain = """$L_{gain} = 30 + 0.4 \cdot (\text{HTL} - 60)$"""
new_lgain = """$L_{gain} = 45 + 1.0 \cdot (\text{HTL} - 60)$"""
text = text.replace(old_lgain, new_lgain)

# Restore the competing mechanisms note
note_pos = text.find("This mechanism mathematically models Outer Hair Cell (OHC) saturation")
if note_pos != -1:
    text = text[:note_pos] + "Because this module forcefully compresses targets for severe thresholds, it directly competes with the Severe-Loss Booster (Section II.F), allowing researchers to natively observe the collision between loudness recruitment (which demands less gain) and profound threshold loss (which demands more gain). " + text[note_pos:]


# 6. Reference List Integrity
# I will use regex or string replace to clean up the bad references and replace them with the accurate ones.
refs_to_replace = [
    ("Engler, S. (2026). \"Dynamic Range Compression and Its Effects,\" Journal of Audiology.", "Engler, M., Digeser, F., & Hoppe, U. (2026). \"Speech Recognition and Real-Ear-Measured Amplification in Hearing-Aid Users With Various Grades of Hearing Loss,\" International Journal of Audiology."),
    ("Pepler, A. (2014). \"Modern hearing aid fitting practices,\" International Journal of Audiology.", "Pepler, A., Munro, K. J., Lewis, K., & Kluk, K. (2014). \"Prevalence of Cochlear Dead Regions in New Referrals and Existing Adult Hearing Aid Users,\" Ear and Hearing."),
    ("Pepler, A. (2015). \"Revisiting prescriptive fitting targets,\" Trends in Amplification.", "Pepler, A., Lewis, K., & Munro, K. J. (2015). \"Adult Hearing-Aid Users With Cochlear Dead Regions Restricted to High Frequencies: Implications for Amplification,\" International Journal of Audiology."),
    ("Windle, R. (2025). \"Next-generation models for prescriptive amplification,\" Hearing Research.", "Windle, R., Dillon, H., & Heinrich, A. (2025). \"Fast versus slow compression in hearing aids: A randomized controlled trial,\" Ear and Hearing."),
    ("Stelmachowicz, P. G., et al. (1985). \"The relationship between hearing loss and speech recognition,\" Ear and Hearing.", "Stelmachowicz, P. G., Lewis, D. E., Larson, L. L., & Jesteadt, W. (1985). \"Upward spread of masking in normal-hearing and hearing-impaired listeners,\" The Journal of the Acoustical Society of America."),
    ("Kuk, F. K., et al. (2003). \"Changing with the times: managing severe-to-profound hearing loss,\" Hearing Review.", "Kuk, F. K., Ludvigsen, C., & Paludan-Muller, C. (2003). \"Improving hearing aid performance in hearing-impaired persons with reverse-slope sensorineural hearing loss,\" Journal of the American Academy of Audiology."),
    ("Byrne, D., et al. (1990). \"An international comparison of long-term average speech spectra,\" The Journal of the Acoustical Society of America.", "Byrne, D., Parkinson, A., & Newall, P. (1990). \"Hearing aid gain and frequency response requirements for the severely/profoundly hearing impaired,\" Ear and Hearing."),
]
for old, new in refs_to_replace:
    text = text.replace(old, new)
    
text = text.replace("""Baltzell, L. S., Swaminathan, J., & Gallun, F. J. (2020). "The impact of age and hearing loss on spatial release from masking," The Journal of the Acoustical Society of America.\n\n""", "")

text = text.replace("""Keidser, G., Dillon, H., Carter, L., & O'Brien, A. (2012). "NAL-NL2 Empirical Adjustments," Trends in Amplification.""", """Keidser, G., Dillon, H., Carter, L., & O'Brien, A. (2012). "NAL-NL2 Empirical Adjustments," Trends in Amplification.

Keidser, G., Dillon, H., Flax, M., Ching, T., & Brewer, S. (2011). "The NAL-NL2 Prescription Procedure," Audiology Research.""")

# Add the missing citations to reference list (Chang 2019, Cox 2011, Cox 2012, Narayanan 2024)
extra_refs = """Chang, Y. S., Park, H., Hong, S. H., et al. (2019). "Predicting Cochlear Dead Regions in Patients With Hearing Loss Through a Machine Learning-Based Approach: A Preliminary Study," PloS One.

Cox, R. M., Alexander, G. C., Johnson, J., & Rivera, I. (2011). "Cochlear Dead Regions in Typical Hearing Aid Candidates: Prevalence and Implications for Use of High-Frequency Speech Cues," Ear and Hearing.

Cox, R. M., Johnson, J. A., & Alexander, G. C. (2012). "Implications of High-Frequency Cochlear Dead Regions for Fitting Hearing Aids to Adults With Mild to Moderately Severe Hearing Loss," Ear and Hearing.

Narayanan, S. K., Rye, P., Houmøller, S. S., et al. (2024). "Difference in SII Provided by Initial Fit and NAL-NL2 and Its Relation to Self-Reported Hearing Aid Outcomes," International Journal of Audiology.\n\n"""
text = text.replace("## ## REFERENCES\n\n", "## REFERENCES\n\n" + extra_refs)
text = text.replace("## ## REFERENCES", "## REFERENCES")

# 7. Introduction Citation String
old_intro_cite = "(Valente et al., 2018; Kuk, 2003; Byrne, 1990; Pepler, 2014; Pepler, 2015; Scollie, 2008; Stelmachowicz, 1985; Windle, 2025; Engler, 2026; Mueller, 2005; Peters, 2000; Pavlovic, 1987; Croteau & Kwok, 2026)"
new_intro_cite = "(Valente et al., 2018; Mueller, 2005)"
text = text.replace(old_intro_cite, new_intro_cite)

# Minor: fix dual section IV
text = text.replace("## IV. CONCLUSION", "## V. CONCLUSION")

# Fix markdown artifact at the end of the bibliography:
text = text.replace("## ## REFERENCES", "## REFERENCES")


with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "w") as f:
    f.write(text)

