import re

with open("R/nalr.R", "r") as f:
    text = f.read()

pattern = r"g_base <- g_base \+ 0\.15 \* pmax\(0, sn_threshold - 60\)"
matches = re.findall(pattern, text)
print("Matches found:", len(matches))

# Let's see what R gsub would do
mod_file = re.sub(pattern, "REPLACED", text)
print("REPLACED in text:", "REPLACED" in mod_file)
