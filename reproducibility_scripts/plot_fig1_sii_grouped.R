library(ggplot2)
library(dplyr)
library(stringr)

raw_text <- "
| A1 (Mild) | 50 | NAL-NL2 | 0.635 | 0.626 | 1.15 |
| A1 (Mild) | 50 | Open-NL | 0.590 | 0.583 | 0.97 |
| A1 (Mild) | 65 | NAL-NL2 | 0.817 | 0.764 | 4.29 |
| A1 (Mild) | 65 | Open-NL | 0.818 | 0.764 | 4.44 |
| A1 (Mild) | 80 | NAL-NL2 | 0.853 | 0.762 | 10.23 |
| A1 (Mild) | 80 | Open-NL | 0.860 | 0.753 | 11.75 |
| A2 (Rev Slope) | 50 | NAL-NL2 | 0.609 | 0.603 | 1.01 |
| A2 (Rev Slope) | 50 | Open-NL | 0.596 | 0.587 | 0.98 |
| A2 (Rev Slope) | 65 | NAL-NL2 | 0.839 | 0.777 | 3.43 |
| A2 (Rev Slope) | 65 | Open-NL | 0.843 | 0.771 | 4.44 |
| A2 (Rev Slope) | 80 | NAL-NL2 | 0.883 | 0.791 | 7.06 |
| A2 (Rev Slope) | 80 | Open-NL | 0.886 | 0.784 | 8.00 |
| A3 (Mod Sloping) | 50 | NAL-NL2 | 0.530 | 0.518 | 0.90 |
| A3 (Mod Sloping) | 50 | Open-NL | 0.541 | 0.534 | 0.91 |
| A3 (Mod Sloping) | 65 | NAL-NL2 | 0.706 | 0.673 | 3.92 |
| A3 (Mod Sloping) | 65 | Open-NL | 0.718 | 0.671 | 4.20 |
| A3 (Mod Sloping) | 80 | NAL-NL2 | 0.777 | 0.695 | 9.82 |
| A3 (Mod Sloping) | 80 | Open-NL | 0.782 | 0.690 | 11.12 |
| A4 (Mod-Severe) | 50 | NAL-NL2 | 0.614 | 0.590 | 1.61 |
| A4 (Mod-Severe) | 50 | Open-NL | 0.562 | 0.537 | 1.16 |
| A4 (Mod-Severe) | 65 | NAL-NL2 | 0.711 | 0.676 | 6.10 |
| A4 (Mod-Severe) | 65 | Open-NL | 0.650 | 0.620 | 5.27 |
| A4 (Mod-Severe) | 80 | NAL-NL2 | 0.749 | 0.689 | 15.76 |
| A4 (Mod-Severe) | 80 | Open-NL | 0.749 | 0.699 | 15.47 |
| A5 (Profound) | 50 | NAL-NL2 | 0.504 | 0.474 | 1.65 |
| A5 (Profound) | 50 | Open-NL | 0.388 | 0.375 | 0.92 |
| A5 (Profound) | 65 | NAL-NL2 | 0.574 | 0.543 | 5.54 |
| A5 (Profound) | 65 | Open-NL | 0.466 | 0.437 | 4.32 |
| A5 (Profound) | 80 | NAL-NL2 | 0.619 | 0.577 | 13.17 |
| A5 (Profound) | 80 | Open-NL | 0.542 | 0.513 | 12.49 |
| A6 (Mixed) | 50 | NAL-NL2 | 0.506 | 0.506 | 0.36 |
| A6 (Mixed) | 50 | Open-NL | 0.563 | 0.561 | 0.65 |
| A6 (Mixed) | 65 | NAL-NL2 | 0.786 | 0.753 | 2.12 |
| A6 (Mixed) | 65 | Open-NL | 0.846 | 0.789 | 3.48 |
| A6 (Mixed) | 80 | NAL-NL2 | 0.881 | 0.801 | 5.40 |
| A6 (Mixed) | 80 | Open-NL | 0.882 | 0.793 | 6.98 |
| A7 (Conductive) | 50 | NAL-NL2 | 0.778 | 0.768 | 0.02 |
| A7 (Conductive) | 50 | Open-NL | 0.847 | 0.831 | 0.08 |
| A7 (Conductive) | 65 | NAL-NL2 | 0.964 | 0.918 | 1.15 |
| A7 (Conductive) | 65 | Open-NL | 0.968 | 0.922 | 1.77 |
| A7 (Conductive) | 80 | NAL-NL2 | 0.991 | 0.945 | 6.66 |
| A7 (Conductive) | 80 | Open-NL | 0.996 | 0.949 | 8.37 |
"

lines <- str_split(raw_text, "\n")[[1]]
lines <- lines[grepl("\\|", lines)]

df <- data.frame(Profile=character(), Level=numeric(), Method=character(), Metric=character(), Value=numeric(), stringsAsFactors=FALSE)

for (line in lines) {
  parts <- str_split(line, "\\|")[[1]]
  parts <- str_trim(parts)
  if (length(parts) < 6) next
  
  profile <- parts[2]
  level <- as.numeric(parts[3])
  method <- parts[4]
  ansi_sii <- as.numeric(parts[5])
  eff_sii <- as.numeric(parts[6])
  
  df <- rbind(df, data.frame(Profile=profile, Level=level, Method=method, Metric="ANSI", Value=ansi_sii))
  df <- rbind(df, data.frame(Profile=profile, Level=level, Method=method, Metric="Effective", Value=eff_sii))
}

# Create a combined grouping variable
df$Group <- factor(paste(df$Method, df$Metric, sep=" - "),
                   levels = c("NAL-NL2 - ANSI", "NAL-NL2 - Effective", "Open-NL - ANSI", "Open-NL - Effective"))

# Custom color palette:
# NAL-NL2 ANSI: Light Blue, NAL-NL2 Eff: Dark Blue
# Open-NL ANSI: Light Red, Open-NL Eff: Dark Red
my_colors <- c("NAL-NL2 - ANSI" = "#89CFF0", "NAL-NL2 - Effective" = "#0047AB",
               "Open-NL - ANSI" = "#FF7F7F", "Open-NL - Effective" = "#B22222")

p <- ggplot(df, aes(x=as.factor(Level), y=Value, fill=Group)) +
  geom_bar(stat="identity", position=position_dodge(width=0.85), width=0.7) +
  facet_wrap(~Profile, ncol=4) +
  scale_fill_manual(values = my_colors) +
  theme_minimal() +
  labs(title="ANSI vs Effective SII: NAL-NL2 vs Open-NL",
       subtitle="Direct comparison of raw physical audibility and desensitized audibility across input levels",
       x="Input Level (dB SPL)",
       y="Speech Intelligibility Index (SII)",
       fill="Prescription & Metric") +
  theme(legend.position="bottom",
        strip.text = element_text(face="bold"),
        panel.grid.major.x = element_blank())

ggsave("/home/mark/Development/SII-github/manuscript_figures/OpenNL_vs_NALNL2_SII_Grouped.png", plot=p, width=12, height=6, dpi=300)
ggsave("/home/mark/.gemini/antigravity/brain/d1572c05-6279-48ca-983d-ed6e97ed4c47/OpenNL_vs_NALNL2_SII_Grouped.png", plot=p, width=12, height=6, dpi=300)
