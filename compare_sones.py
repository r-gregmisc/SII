import csv
import math

r_sones = {}
with open('r_sones_a1_a7.csv') as f:
    reader = csv.reader(f)
    next(reader)
    for row in reader:
        r_sones[row[0]] = float(row[1])

oct_sones = {}
with open('octave_sones_a1_a7.csv') as f:
    reader = csv.reader(f)
    next(reader)
    for row in reader:
        oct_sones[row[0]] = float(row[1])

print("Profile | R_Sones | Octave_Sones | Diff")
print("--------|---------|--------------|-------")
sum_sq = 0
max_rel = 0
for p in r_sones.keys():
    r = r_sones[p]
    o = oct_sones[p]
    diff = r - o
    rel = abs(diff) / o if o > 0 else 0
    sum_sq += diff**2
    if rel > max_rel: max_rel = rel
    print(f"{p:7} | {r:7.4f} | {o:12.4f} | {diff:6.4f}")

rmse = math.sqrt(sum_sq / len(r_sones))
print(f"RMSE: {rmse:.4f}")
print(f"Max Relative Diff: {max_rel:.2%}")
