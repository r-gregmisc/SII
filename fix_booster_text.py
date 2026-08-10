with open("OpenNL_manuscript.md", "r") as f:
    text = f.read()

bad_text = "The surface demonstrates that for severe profiles (A4, A5), loudness initially rises but quickly hits a saturation ceiling as the booster magnitude increases. This saturation visually confirms that the downstream modules successfully contain the uncapped booster."
good_text = "The surface demonstrates that for severe profiles (A4, A5), physiological loudness is essentially invariant to the booster magnitude at standard conversational input levels (65 dB SPL). This confirms the physiological safety of the uncapped booster: because it operates exclusively in regions of profound deafness (70+ dB HL), the amplified high-frequency output remains below or near the patient's absolute threshold of hearing, generating negligible additional loudness while maximizing available cues."

text = text.replace(bad_text, good_text)

with open("OpenNL_manuscript.md", "w") as f:
    f.write(text)
