import re

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "r") as f:
    text = f.read()

old_list_start = "The modules described below are not applied simultaneously; rather, they operate in a strictly defined cascaded execution order"
old_list_end = "12. Finally, subtract age-specific RECD scaling penalties for infants"

start_idx = text.find(old_list_start)
end_idx = text.find(old_list_end) + len("12. Finally, subtract age-specific RECD scaling penalties for infants (Section II.L).")

# If it ends with something slightly different, let's just find the next section "### A. Minimal hearing loss"
next_section_idx = text.find("### A. Minimal hearing loss")

old_block = text[start_idx:next_section_idx]

new_block = """The modules described below are not applied simultaneously; rather, they operate in a strictly defined cascaded execution order to prevent unintended interactions between additive boosters and soft limiters. The execution order is as follows:

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
12. Finally, subtract age-specific RECD scaling penalties for infants (Section II.M).


"""

text = text.replace(old_block, new_block)

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "w") as f:
    f.write(text)

