import re

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "r") as f:
    text = f.read()

# 1. Dead Region and Booster
old_dead = r"""### F. Dead region detection and the severe-loss booster

Because foundational half-gain rules chronically under-amplify severe-to-profound losses, Open-NL incorporates a **Severe-Loss Booster**. It is well documented in prescriptive literature that listeners with severe-to-profound hearing loss require significantly more gain than predicted by a strict linear or half-gain function to achieve audibility, owing to extensive inner hair cell damage and the need for higher signal-to-noise ratios (Byrne et al., 1990; Keidser et al., 2011). For any threshold exceeding 60 dB HL, gain is boosted by half the exceeding amount, capped at a maximum 15 dB boost, and applied directly to the base target gain:
\begin{equation}
\text{Boost} = \min\left(15, 0.5 \cdot \max\left(0, \text{HTL}_{sn} - 60\right)\right)
\end{equation}
\begin{equation}
G_{65} = G_{65} + \text{Boost}
\end{equation}

However, Open-NL automatically scans the audiogram to infer likely cochlear dead regions ($\text{HTL} \ge 90$ dB). It must be explicitly cautioned that inferring dead regions from audiometric thresholds alone is unreliable; clinical best practice relies on the Threshold-Equalizing Noise (TEN) test (Moore, 2001). This threshold-based trigger is implemented as a tunable parameter rather than a validated rule. To prevent pumping massive, distorted gain into completely dead inner hair cell regions (Moore, 2001)—which provides no speech intelligibility benefit and risks tactile discomfort—the booster is smoothly tapered to zero over a 1-octave boundary."""

new_dead = r"""### F. Dead region detection and the severe-loss booster

Open-NL explicitly leaves dead-region gain reductions disabled by default. While profound hearing loss implies severe Outer Hair Cell (OHC) damage, evidence indicates that pure-tone thresholds and audiometric slopes cannot reliably identify cochlear dead regions (Cox et al., 2011; Chang et al., 2019). Furthermore, in adults with mild-to-moderately-severe loss, providing full high-frequency gain has not been shown to produce poorer performance, making threshold-inferred tapering a priori indefensible (Cox et al., 2012; Pepler et al., 2014; Pepler et al., 2015).

Instead, Open-NL provides a severe-loss booster aligned with the Byrne et al. (1990) finding that half-gain logic ceases to be optimal above $\sim 70$ dB HL, requiring up to 10 dB of additional insertion gain for severe-to-profound configurations. Open-NL achieves this by scaling the anchor (Equation 2) directly, without requiring an additive Boost equation:
\begin{equation}
G_{anchor} = \min(0.46 \cdot \text{HTL}, 0.46 \cdot \text{HTL} + \min(10, 0.15 \cdot \max(0, \text{HTL} - 70)))
\end{equation}
This explicitly bounds the severe-loss boost to 10 dB, maintaining physiological safety without relying on inaccurate dead-region inference."""

text = text.replace(old_dead, new_dead)

# 2. L_gain formula
old_lgain = r"""L_{gain} = 30 + 0.4 \cdot \max\left(0, \text{HTL}_{sn} - 60\right)"""
new_lgain = r"""L_{gain} = 45 + 1.0 \cdot \max\left(0, \text{HTL}_{sn} - 60\right)"""
text = text.replace(old_lgain, new_lgain)


with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "w") as f:
    f.write(text)

