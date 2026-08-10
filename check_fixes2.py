import re

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "r") as f:
    text = f.read()

print("Anchor reframed:", "multiplier of 0.46" in text and "unvalidated free parameter" in text)
print("Eq 11 Lgain labeled:", "explicitly designated as an unvalidated free parameter" in text)
print("Eq 16/17 labeled:", "reduction heuristic is designated as an unvalidated free parameter" in text)
print("SD-LFP fixed:", "massive loudness summation across auditory filters" in text)
print("Reverse slope fixed:", "inverse logic may be appropriate" in text and "Kuk et al., 2003" in text)
print("Summary performance stripped:", "Open-NL successfully generates physiologically scaled WDRC targets" in text)
print("Octave validation added:", "Auditory Modeling Toolbox (AMT)" in text)
print("Table I updated:", "Open-NL (50 dB SPL)" in text)
print("Minor fixes:", "conservatively serves" in text, "Bagatto et al., 2002" in text, "Section II.M" in text, "Narayanan et al., 2024" in text)
