with open("OpenNL_manuscript.md", "r") as f:
    text = f.read()

# Replace Title
text = text.replace("Open-NL: A Transparent Computational Heuristic for Wide Dynamic Range Compression",
                    "Open-NL: An Open-Source Constrained Optimization Engine for Wide Dynamic Range Compression")

# Abstract rewrite
text = text.replace(
"""Open-NL, an open-source prescriptive algorithm, derives dynamic Wide Dynamic Range Compression (WDRC) targets in R. While the derivations of major algorithms like NAL-NL2 are published in detail, their compiled software implementations are closed-source, preventing researchers from testing component-level hypotheses. Open-NL provides a modifiable substrate permitting component-level ablation of prescriptive rules. It utilizes a Slope-Dependent Low-Frequency Penalty (SD-LFP) that scales gain based on threshold severity, applying a mathematically defined low-frequency attenuation to steeply sloping audiograms. Primarily serving as an intelligibility-protection module, an embedded loudness engine demonstrates that Open-NL's SD-LFP salvages speech understanding from upward spread of masking while simultaneously preventing the profound loudness recruitment (A5) typical of unconstrained half-gain heuristics. The framework further implements an uncapped Severe-Loss Booster that relies strictly on downstream parameter collisions for physiological safety. The algorithm is strictly a computational toolkit designed for researchers to model and modify insertion gain dynamics; it conservatively serves as a baseline that often undershoots WDRC loudness, and it has not undergone behavioral validation for clinical use.""",
"""Open-NL, an open-source prescriptive algorithm, derives dynamic Wide Dynamic Range Compression (WDRC) targets in R via formal constrained optimization. While major algorithms like NAL-NL2 derive their targets through optimization, their compiled implementations are closed-source, obscuring their objective functions. Open-NL resolves this by explicitly deploying an L-BFGS-B optimization loop natively within R. The engine maximizes the Speech Intelligibility Index (SII) subject to a strict dynamic physiological loudness ceiling (capped at 20 sones for a 65 dB SPL input) calculated via an embedded Moore & Glasberg (2004) loudness model. To ensure rapid convergence and avoid local minima, the optimizer is seeded by an intelligent cascaded heuristic featuring a Slope-Dependent Low-Frequency Penalty (SD-LFP) and a Severe-Loss Booster. This architecture mathematically guarantees physiological safety across untested audiometric boundaries without relying on heuristic parameter collisions. Open-NL provides researchers with a completely transparent, modifiable optimization substrate for WDRC target generation, though it has not undergone behavioral validation for clinical use."""
)

# Introduction rewrite (end of intro)
text = text.replace(
"""Open-NL provides a parameterized, inspectable research testbed to solve this problem. It is designed as a modular substrate permitting component-level ablation of prescriptive rules, where individual heuristic components---such as slope-dependent penalties or severe-loss boosters---can be independently toggled and their physiological consequences directly measured.""",
"""Open-NL provides a parameterized, inspectable research testbed to solve this problem. It is designed as a transparent constrained-optimization engine. Researchers can directly inspect and modify the objective function, alter the mathematical bounds of the physiological loudness ceiling, and independently toggle the heuristic initialization seeds that guide the optimizer."""
)

# Section II Intro
text = text.replace(
"""## II. THE OPEN-NL PRESCRIPTIVE ALGORITHM: ALGORITHMIC ARCHITECTURE

Open-NL operates as a multi-stage parameterized shape generator. Rather than relying on static compiled lookup tables, Open-NL calculates target insertion gains dynamically through a series of explicitly defined cascaded mathematical modules. Each step in the gain derivation process is exposed natively in R, available for researchers to inspect, modify, and tune.""",
"""## II. THE OPEN-NL OPTIMIZATION ENGINE: ALGORITHMIC ARCHITECTURE

Open-NL operates as a formal constrained optimization engine. Rather than relying on static compiled lookup tables, Open-NL derives target insertion gains by deploying the L-BFGS-B optimization algorithm to maximize the Speech Intelligibility Index (SII) subject to a hard physiological loudness constraint. To ensure the optimizer converges rapidly and avoids poor local minima, the target is first initialized by a highly-tuned cascaded mathematical heuristic seed. This seed process is exposed natively in R, available for researchers to inspect, modify, and tune."""
)

# Section II.C (SD-LFP) rename
text = text.replace(
"### C. Slope-Dependent Low-Frequency Penalty (SD-LFP) for Intelligibility Protection",
"### C. Heuristic Seed Phase 1: Slope-Dependent Low-Frequency Penalty (SD-LFP)"
)

# Section II.F (Severe-loss booster) rename
text = text.replace(
"### F. Dead region detection and the severe-loss booster",
"### F. Heuristic Seed Phase 2: The severe-loss booster"
)

# Section II.D (Ablation and Sensitivity Analysis) -> The Objective Function and Loudness Cap
old_iid = text.find("### D. Ablation and Sensitivity Analysis")
old_iie = text.find("### E. Mid-frequency salvage boost")
if old_iid != -1 and old_iie != -1:
    replacement = """### D. The Objective Function and Dynamic Loudness Cap

While the heuristic seeds generate a baseline shape, the core of Open-NL is its optimization loop. NAL-NL2 utilizes a neural-network derived optimization to maximize SII subject to a global loudness ceiling. Open-NL mirrors this conceptual architecture via a transparent, embedded L-BFGS-B optimization algorithm. 

The objective function computes the aided speech spectrum for the proposed insertion gain array and evaluates it using the ANSI S3.5-1997 SII standard. Simultaneously, the array is processed through a hybrid Chen et al. (2011) and Moore & Glasberg (2004) loudness model. If the predicted monaural loudness exceeds a hard physiological ceiling of 20.0 sones (for a 65 dB SPL input), a heavy mathematical penalty is applied to the gradient. The optimizer iteratively fine-tunes the gain across all frequency bands until it finds the absolute maximum SII that strictly complies with the 20-sone constraint. This explicitly guarantees physiological safety and replaces fragile architectural reliance on heuristic parameter collisions.

"""
    text = text[:old_iid] + replacement + text[old_iie:]


# Remove Section V (Theoretical Limitations) that I just added
old_v = text.find("## V. THEORETICAL LIMITATIONS")
old_vi = text.find("## VI. CONCLUSION")
if old_v != -1 and old_vi != -1:
    text = text[:old_v] + text[old_vi:]
    text = text.replace("## VI. CONCLUSION", "## V. CONCLUSION")

with open("OpenNL_manuscript.md", "w") as f:
    f.write(text)
