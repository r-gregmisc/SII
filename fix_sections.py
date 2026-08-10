import re

with open("OpenNL_manuscript.md", "r") as f:
    text = f.read()

# 1. Update the execution list
old_list = """1. Generate baseline Half-Gain anchor (Section II.A).
2. Apply Slope-Dependent Low-Frequency Penalty (SD-LFP) for recruitment mitigation (Section II.B).
3. Run Nelder-Mead Optimization subject to dynamic loudness ceiling (Section II.C).
4. Apply Mid-frequency salvage boost (Section II.D).
5. Apply Severe-loss high-frequency boost and Dead Region tapering (Section II.E).
6. Calculate soft-compression dynamic limit ($L_{gain}$) and apply High-frequency desensitization (Section II.F).
7. Calculate dynamic Compression Ratios (CR) based on thresholds (Section II.G).
8. Integrate Conductive Component correction (+75% ABG) with a 30 dB cap and global ceiling (Section II.H).
9. Apply MPO-domain saturation limit to ensure output safety (Section II.I).
10. Apply Comfort in Noise (CIN) WDRC alterations if triggered (Section II.J).
11. Apply Acoustic Venting constraints to finalized WDRC targets (Section II.K).
12. Finally, subtract age-specific RECD scaling penalties for infants (Section II.L)."""

new_list = """1. Generate baseline Half-Gain anchor (Section II.A).
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
12. Finally, run Nelder-Mead Optimization subject to dynamic loudness ceiling (Section II.L)."""

text = text.replace(old_list, new_list)

# 2. Extract Section II.C
match = re.search(r'(### C\. The Objective Function and Dynamic Loudness Cap\n\n.*?)(?=### D\. Mid-frequency salvage boost\n)', text, re.DOTALL)
if match:
    objective_text = match.group(1)
    text = text.replace(objective_text, "")
    
    # We need to insert it before "### A. Quantitative Loudness Engine Verification"
    # But wait, Quantitative Loudness Engine Verification is a subsection of Section III, wait, let's see where Section III is.
    # Ah, let's just insert it right before "### A. Quantitative Loudness Engine Verification" or rather at the end of Section II.
    
    # Wait, the sections are:
    # ### K. Acoustic venting and signal purity
    # ...
    # ### L. Infant RECD scaling
    # ...
    
    # I'll just find "### L. Infant RECD scaling" block and put it after.
    
    match2 = re.search(r'(### L\. Infant RECD scaling\n\n.*?)(?=\*\*TABLE I\. Theoretical SII)', text, re.DOTALL)
    if match2:
        recd_text = match2.group(1)
        new_objective_text = objective_text.replace("### C. The Objective Function and Dynamic Loudness Cap", "### L. The Objective Function and Dynamic Loudness Cap")
        new_objective_text = new_objective_text.replace("Section II.D", "Section II.L") # Fix references
        
        # Now I need to reletter D through L to C through K
        text = text.replace("### D. Mid-frequency salvage boost", "### C. Mid-frequency salvage boost")
        text = text.replace("### E. Heuristic Seed Phase 2: The severe-loss booster", "### D. Heuristic Seed Phase 2: The severe-loss booster")
        text = text.replace("### F. Soft-compression high-frequency desensitization", "### E. Soft-compression high-frequency desensitization")
        text = text.replace("### G. Dynamic WDRC computation (compression ratios)", "### F. Dynamic WDRC computation (compression ratios)")
        text = text.replace("### H. Conductive component correction", "### G. Conductive component correction")
        text = text.replace("### I. MPO-domain saturation limit", "### H. MPO-domain saturation limit")
        text = text.replace("### J. Comfort in noise (CIN) module", "### I. Comfort in noise (CIN) module")
        text = text.replace("### K. Acoustic venting and signal purity", "### J. Acoustic venting and signal purity")
        text = text.replace("### L. Infant RECD scaling", "### K. Infant RECD scaling")
        
        # Now find the NEW K. Infant RECD scaling and append L. after it
        match3 = re.search(r'(### K\. Infant RECD scaling\n\n.*?)(?=\*\*TABLE I\. Theoretical SII)', text, re.DOTALL)
        if match3:
            new_recd = match3.group(1)
            text = text.replace(new_recd, new_recd + "\n" + new_objective_text + "\n")
            
            with open("OpenNL_manuscript.md", "w") as f:
                f.write(text)
            print("Successfully reorganized sections.")
        else:
            print("Error: Could not find new K. Infant RECD scaling")
    else:
        print("Error: Could not find L. Infant RECD scaling")
else:
    print("Error: Could not extract objective function text")
