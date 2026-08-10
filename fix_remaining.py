import re

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "r") as f:
    text = f.read()

# 1. Conductive component
old_abg = """For mixed hearing losses, Open-NL restores 75% of the air-bone gap (ABG) as linear gain. This formally implements the 75% ABG + BC convention (Johnson, 2013), ensuring that the compression ratio tracks only the sensorineural component. It should be noted that whether listeners prefer exactly 75% restoration remains an unresolved empirical question. To prevent upward spread of masking, an original Open-NL 6 dB low-frequency taper is uniquely applied to this ABG gain, smoothly fading out by 1000 Hz."""
new_abg = """For mixed hearing losses, Open-NL restores 75% of the air-bone gap (ABG) as linear gain. This formally implements the 75% ABG + BC convention (Johnson, 2013), ensuring that the compression ratio tracks only the sensorineural component. However, massive, uncapped ABG restorations risk generating output SPLs capable of permanently damaging the remaining sensorineural capacity. To enforce safety, Open-NL strictly caps the ABG restoration at 30 dB and enforces a global ceiling where total insertion gain cannot exceed 85% of the total threshold. To prevent upward spread of masking, an original Open-NL 6 dB low-frequency taper is uniquely applied to this ABG gain, smoothly fading out by 1000 Hz. This aligns with threshold-shift risk modeling which estimates that prescriptive gains become unsafe above 90 dB HL (NAL-NL2) or 80 dB HL (DSL m[i/o]) (Narayanan et al., 2024)."""
text = text.replace(old_abg, new_abg)

# 2. L_gain formula
old_lgain = """L_{gain} = 30 + 0.4 \cdot \max\left(0, \text{HTL}_{sn} - 60\\right)"""
new_lgain = """L_{gain} = 45 + 1.0 \cdot \max\left(0, \text{HTL}_{sn} - 60\\right)"""
text = text.replace(old_lgain, new_lgain)

# Also add the note about competing mechanisms right after equation 10 (Wait, it's now Equation 11 or 12).
# Let's search for "If the calculated target gain ($G_{65}$) exceeds this dynamic limit"
old_lgain_desc = """If the calculated target gain ($G_{65}$) exceeds this dynamic limit"""
new_lgain_desc = """Because this module forcefully compresses targets for severe thresholds, it directly competes with the Severe-Loss Booster (Section II.F), allowing researchers to natively observe the collision between loudness recruitment (which demands less gain) and profound threshold loss (which demands more gain). If the calculated target gain ($G_{65}$) exceeds this dynamic limit"""
text = text.replace(old_lgain_desc, new_lgain_desc)


with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "w") as f:
    f.write(text)

