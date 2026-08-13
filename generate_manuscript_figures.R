library(ggplot2)
library(tidyr)

# Data for Figure 1 and 2 (from updated Table I)
data_perf <- data.frame(
  Profile = rep(paste0("A", 1:7), each=2),
  Prescription = rep(c("NAL-NL2", "Open-NL"), 7),
  SII = c(0.80, 0.86, 0.88, 0.89, 0.73, 0.82, 0.80, 0.83, 0.67, 0.72, 0.87, 0.84, 0.69, 0.95),
  Loudness = c(14.0, 9.3, 2.4, 5.1, 10.6, 8.9, 14.4, 14.6, 11.0, 11.0, 6.1, 4.8, 5.8, 11.0)
)

# Figure 1: SII
p1 <- ggplot(data_perf, aes(x=Profile, y=SII, fill=Prescription)) +
  geom_bar(stat="identity", position="dodge", color="black", width=0.7) +
  theme_bw(base_size=16) +
  labs(title="Speech Intelligibility Index Maximization (65 dB SPL)", y="Speech Intelligibility Index (SII)", x="Audiometric Profile") +
  scale_fill_manual(values=c("NAL-NL2"="#999999", "Open-NL"="#2c7fb8")) +
  theme(legend.position="bottom", plot.title=element_text(hjust=0.5)) +
  coord_cartesian(ylim=c(0, 1.0))

ggsave("Figure1_Optimization_SII.png", p1, width=9, height=6, dpi=300)

# Figure 2: Loudness
p2 <- ggplot(data_perf, aes(x=Profile, y=Loudness, fill=Prescription)) +
  geom_bar(stat="identity", position="dodge", color="black", width=0.7) +
  theme_bw(base_size=16) +
  labs(title="Physiological Loudness Optimization (65 dB SPL)", y="Monaural Loudness (Sones)", x="Audiometric Profile") +
  scale_fill_manual(values=c("NAL-NL2"="#999999", "Open-NL"="#e34a33")) +
  theme(legend.position="bottom", plot.title=element_text(hjust=0.5))

ggsave("Figure2_Optimization_Loudness.png", p2, width=9, height=6, dpi=300)

# Data for Figure 3 (from updated Table II)
data_gain <- data.frame(
  Profile = rep(paste0("A", 1:7), each=12),
  Prescription = rep(rep(c("NAL-NL2", "Open-NL"), each=6), 7),
  Freq = rep(c(250, 500, 1000, 2000, 4000, 8000), 14),
  Gain = c(
    # A1
    14.0, 20.0, 22.0, 20.0, 17.0, 12.0,
    0.0, 8.3, 16.7, 19.1, 24.3, 13.8,
    # A2
    20.0, 16.0, 12.0, 6.0, 2.0, 2.0,
    13.3, 20.0, 21.2, 14.8, 9.3, 4.0,
    # A3
    6.0, 16.0, 22.0, 22.0, 16.0, 6.0,
    0.0, 8.3, 21.2, 26.3, 28.1, 13.9,
    # A4
    0.0, 0.0, 0.0, 16.0, 31.0, 30.0,
    0.0, 0.0, 0.0, 19.1, 37.0, 20.5,
    # A5
    0.0, 0.0, 15.0, 28.0, 30.0, 30.0,
    0.0, 0.1, 12.0, 30.4, 41.0, 26.2,
    # A6
    30.0, 32.0, 40.0, 42.0, 45.0, 45.0,
    18.2, 29.8, 39.4, 41.2, 44.4, 33.9,
    # A7
    14.0, 15.0, 17.0, 18.0, 18.0, 18.0,
    17.6, 27.0, 30.5, 28.6, 27.6, 32.7
  )
)

p3 <- ggplot(data_gain, aes(x=Freq, y=Gain, color=Prescription, linetype=Prescription, shape=Prescription)) +
  geom_line(linewidth=1.2) +
  geom_point(size=3) +
  facet_wrap(~Profile, scales="fixed") +
  theme_bw(base_size=14) +
  scale_x_log10(breaks=c(250, 500, 1000, 2000, 4000, 8000), labels=c("250", "500", "1k", "2k", "4k", "8k")) +
  labs(title="Insertion Gain Targets (65 dB SPL Input)", x="Frequency (Hz)", y="Insertion Gain (dB)") +
  scale_color_manual(values=c("NAL-NL2"="#999999", "Open-NL"="#2ca25f")) +
  theme(legend.position="bottom", plot.title=element_text(hjust=0.5))

ggsave("Figure3_Insertion_Gain.png", p3, width=12, height=8, dpi=300)

cat("Successfully generated Figure1_Optimization_SII.png, Figure2_Optimization_Loudness.png, and Figure3_Insertion_Gain.png in the root directory.\n")
