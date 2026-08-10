import re

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "r") as f:
    text = f.read()

print("MPO present:", "MPO-domain saturation ceiling" in text)
print("ABG cap present:", "caps the ABG restoration at 30 dB" in text)
print("RECD caveat present:", "accuracy of only ~54% to 62%" in text)
print("Digitization caveat present:", "margin of error which can produce" in text)
print("Dead region disabled:", "leaves dead-region gain reductions disabled" in text)
print("Tautology removed:", "fundamental circularity" not in text)
print("New tautology present:", "carries no tautological advantage" in text)
print("Summary arithmetic:", "average 8.68 and 9.92 sones" in text)
print("Double Boost Eq 10:", "Boost =" in text)
print("L_gain fixed:", "45 + 1.0" in text)
print("Ref Pepler fixed:", "Prevalence of Cochlear Dead Regions" in text)
print("Ref Baltzell removed:", "Baltzell" not in text)
