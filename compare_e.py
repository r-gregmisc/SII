import csv

with open('r_excitation.csv') as f:
    next(f) # skip header
    r_e = [float(row[0]) for row in csv.reader(f)]

with open('octave_excitation.csv') as f:
    oct_e = [float(row[0]) for row in csv.reader(f)]

diffs = [abs(r - o) for r, o in zip(r_e, oct_e)]
max_diff = max(diffs)
rel_diffs = [d / max(o, 1e-10) for d, o in zip(diffs, oct_e)]
max_rel = max(rel_diffs)

print(f"Max absolute diff: {max_diff:.3e}")
print(f"Max relative diff: {max_rel:.3%}")
