a_profiles = {
  'A1': [0, 0, 0, 0, 0, 0],
  'A2': [40, 40, 30, 20, 10, 10],
  'A3': [10, 10, 15, 30, 40, 50],
  'A4': [70, 70, 70, 70, 70, 70],
  'A5': [10, 10, 20, 60, 80, 100],
  'A6': [50, 55, 60, 65, 75, 80],
  'A7': [50, 50, 50, 50, 50, 50]
}
for name, p in a_profiles.items():
    pta_lf = sum(p[0:3])/3
    pta_hf = sum(p[3:6])/3
    print(f"{name}: LF={pta_lf:.1f}, HF={pta_hf:.1f}, Slope={pta_hf - pta_lf:.1f}")
