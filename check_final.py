import re

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "r") as f:
    text = f.read()

print("Table I regenerated:", "66.6" in text and "11.3" in text)
print("A2 deleted:", "outperforming" not in text)
print("A7 deleted:", "highly competitive" not in text)
print("Windle fixed:", "heuristic assumption that adult patients" in text and "degraded temporal processing" not in text)
print("Octave Table added:", "Absolute Error" in text)
print("Ching Intro:", "marked effects on predicted loudness (Ching et al., 2013)" in text)
print("Narayanan Sec III:", "threshold-shift risks at high outputs (Narayanan et al., 2024)" in text)
