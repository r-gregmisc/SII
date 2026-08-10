import re

with open("OpenNL_manuscript.md", "r") as f:
    text = f.read()

bad_text = " It is crucial to note that for some profiles like A6 (which has 50–60 dB HL low-frequency hearing loss), variations in the penalty magnitude appear inert. This is not a parameter failure, but a physiological feature: restoring 10 dB of gain in a deaf region at a 65 dB SPL input does not cross the physiological absolute threshold of hearing. The acoustic output changes, but it contributes zero sones because it is essentially inaudible."

text = text.replace(bad_text, "")

with open("OpenNL_manuscript.md", "w") as f:
    f.write(text)
