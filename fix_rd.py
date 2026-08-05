import re

with open('man/sii.Rd', 'r') as f:
    text = f.read()

# Add missing args to usage block
usage_find = "distortion_category=NULL)"
usage_repl = "distortion_category=NULL,\n    ten_edge_hf=NULL,\n    ten_edge_lf=NULL)"
if usage_find in text:
    text = text.replace(usage_find, usage_repl)

# Add missing args to arguments block
arg_find = "distortion_category}{Distortion category"
arg_repl = r"distortion_category}{Distortion category (""Normal"", ""Low"", ""Moderate"", ""High"").}\n  \item{ten_edge_hf}{High-frequency dead region edge (optional).}\n  \item{ten_edge_lf}{Low-frequency dead region edge (optional)."

text = re.sub(r"distortion_category\}\{.*?\}", arg_repl, text, flags=re.DOTALL)

with open('man/sii.Rd', 'w') as f:
    f.write(text)

with open('man/calculate_loudness.Rd', 'r') as f:
    text2 = f.read()

usage_find2 = "calculate_loudness(x)"
usage_repl2 = "calculate_loudness(x, ohc_proportion = 0.65)"
if usage_find2 in text2:
    text2 = text2.replace(usage_find2, usage_repl2)

arg_find2 = r"(\s*\\item\{x\}\{)"
text2 = re.sub(arg_find2, r"\n  \\item{ohc_proportion}{Outer hair cell loss proportion (default: 0.65).}\1", text2)

with open('man/calculate_loudness.Rd', 'w') as f:
    f.write(text2)
