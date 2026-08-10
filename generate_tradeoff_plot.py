import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from adjustText import adjust_text

df = pd.read_csv("tradeoff_results_corrected.csv")

plt.figure(figsize=(9, 6))
sns.set_style("whitegrid")

for formula in df['Formula'].unique():
    subset = df[df['Formula'] == formula]
    plt.plot(subset['Sones'], subset['SII'], marker='o', label=formula)

texts = []
for i, row in df.iterrows():
    texts.append(plt.text(row['Sones'], row['SII'], f"{row['Audiogram']}-{row['Formula']}", fontsize=8))

adjust_text(texts, arrowprops=dict(arrowstyle='-', color='gray', lw=0.5))

plt.title("Theoretical SII vs Monaural Loudness (A1-A7 Profiles)")
plt.xlabel("Monaural Loudness (Sones)")
plt.ylabel("Speech Intelligibility Index (SII)")
plt.legend()
plt.tight_layout()
plt.savefig("tradeoff_plot.png", dpi=300)
print("Plot generated as tradeoff_plot.png")
