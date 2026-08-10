with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "r") as f:
    text = f.read()

# Fix the backspace \x08 and tab \t characters
text = text.replace("0.0 \le \text{SII} \le 1.0$)", r"0.0 \le \text{SII} \le 1.0$)")
text = text.replace("0.0 \le \t" + "ext{SII} \le 1.0$)", r"0.0 \le \text{SII} \le 1.0$)")
text = text.replace("\x08egin{equation}", r"\begin{equation}")
text = text.replace("\text{Predicted WRS", r"\text{Predicted WRS")
text = text.replace("\t" + "ext{Predicted WRS", r"\text{Predicted WRS")
text = text.replace("^{-(\text{SII}", r"^{-(\text{SII}")
text = text.replace("^{-(\t" + "ext{SII}", r"^{-(\text{SII}")

with open("/home/mark/Development/SII-github/OpenNL_manuscript.md", "w") as f:
    f.write(text)

with open("/home/mark/snap/antigravity/5/.gemini/antigravity/brain/801be6c5-53e7-4f14-a048-b07d402324a7/manuscript_final.md", "w") as f:
    f.write(text)
