import re

with open("R/nalr.R", "r") as f:
    text = f.read()

pattern = r"g_base <- g_base \+ 0\.15 \* pmax\(0, sn_threshold - 60\)"
matches = re.findall(pattern, text)
print("Matches found:", len(matches))
