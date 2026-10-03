#!/usr/bin/env Rscript
library(ggplot2)
library(patchwork)

source("reproducibility_scripts/helpers_jaaa.R")

in_dir <- "reproducibility_scripts/output/jaaa_audmod"
out_dir <- file.path(in_dir, "figures")
dir.create(out_dir, showWarnings = FALSE)

# Profile Mapping
profile_names_map <- c(
  "a1" = "A1: Mild",
  "a2" = "A2: Reverse slope",
  "a3" = "A3: Moderate sloping",
  "a4" = "A4: Moderate-to-severe precipitous",
  "a5" = "A5: Profound precipitous",
  "a6" = "A6: Mixed",
  "a7" = "A7: Conductive"
)

# ---------------------------------------------------------
# FIGURE A: Feasibility
# ---------------------------------------------------------
feas_df <- read.csv(file.path(in_dir, "feasibility_grid.csv"))
table2_df <- read.csv(file.path(in_dir, "table2_iso_loudness.csv"))

profiles_figA <- c("a4", "a5")
feas_sub <- feas_df[feas_df$Profile %in% profiles_figA, ]

# Compute feasible cells
feas_sub$Feasible <- feas_sub$Loudness <= 1.01 * feas_sub$L_cap
feas_sub$HF_Gain_plot <- ifelse(feas_sub$Feasible, feas_sub$HF_Gain, NA)
feas_sub$SII_smoothed_plot <- ifelse(feas_sub$Feasible, feas_sub$SII_smoothed, NA)

norm_cap <- lcap(65)

# Calculate unaided loudness for A4 and A5
unaided_a4 <- loudness_of(65, rep(0, 6), jd2011_targets[["a4"]]$threshold, rep(0, 6))$total
unaided_a5 <- loudness_of(65, rep(0, 6), jd2011_targets[["a5"]]$threshold, rep(0, 6))$total

nal_pts <- data.frame(Profile = character(), L_cap = numeric(), vent_floor = numeric(), HF_Gain = numeric(), SII = numeric(), SII_smooth = numeric(), stringsAsFactors = FALSE)
for (p in profiles_figA) {
  row <- table2_df[table2_df$Profile == p, ]
  hf_gain <- mean(c(row$NAL_G2000, row$NAL_G4000))
  nal_pts <- rbind(nal_pts, data.frame(
    Profile = p,
    L_cap = row$NAL_Loudness,
    vent_floor = 0,
    HF_Gain = hf_gain,
    SII = row$NAL_SII_Desens,
    SII_smooth = row$NAL_SII_Smooth
  ))
}

lim_gain <- range(feas_sub$HF_Gain_plot, na.rm = TRUE)
lim_sii <- range(feas_sub$SII_smoothed_plot, na.rm = TRUE)

p_a4_gain <- ggplot(feas_sub[feas_sub$Profile == "a4", ], aes(x = L_cap, y = vent_floor, fill = HF_Gain_plot)) +
  geom_tile() +
  geom_vline(xintercept = norm_cap, linetype = "dashed", color = "grey20", linewidth = 0.8) +
  geom_vline(xintercept = unaided_a4, linetype = "dotted", color = "grey20", linewidth = 0.8) +
  annotate("text", x = norm_cap + 0.15, y = 1.5, label = "Normal hearing", color = "grey20", angle = 0, hjust = 0, size = 3.2) +
  annotate("text", x = unaided_a4 + 0.15, y = 1.5, label = "Unaided", color = "grey20", angle = 0, hjust = 0, size = 3.2) +
  geom_point(data = nal_pts[nal_pts$Profile == "a4", ], aes(x = L_cap, y = vent_floor), color = "red", shape = 4, size = 3, stroke = 1.5, inherit.aes = FALSE) +
  geom_label(data = nal_pts[nal_pts$Profile == "a4", ], aes(x = L_cap, y = vent_floor + 1.2, label = sprintf("%.1f dB", HF_Gain)), fill = "white", label.size = 0, color = "red", fontface = "bold", inherit.aes = FALSE) +
  scale_fill_viridis_c(name = "2-4 kHz gain (dB)", option = "viridis", limits = lim_gain, na.value = "grey80") +
  labs(x = "Loudness cap (sones)", y = "Minimum insertion gain (dB)", subtitle = profile_names_map["a4"]) +
  theme_minimal()

p_a5_gain <- ggplot(feas_sub[feas_sub$Profile == "a5", ], aes(x = L_cap, y = vent_floor, fill = HF_Gain_plot)) +
  geom_tile() +
  geom_vline(xintercept = norm_cap, linetype = "dashed", color = "grey20", linewidth = 0.8) +
  geom_vline(xintercept = unaided_a5, linetype = "dotted", color = "grey20", linewidth = 0.8) +
  geom_point(data = nal_pts[nal_pts$Profile == "a5", ], aes(x = L_cap, y = vent_floor), color = "red", shape = 4, size = 3, stroke = 1.5, inherit.aes = FALSE) +
  geom_label(data = nal_pts[nal_pts$Profile == "a5", ], aes(x = L_cap, y = vent_floor + 1.2, label = sprintf("%.1f dB", HF_Gain)), fill = "white", label.size = 0, color = "red", fontface = "bold", inherit.aes = FALSE) +
  scale_fill_viridis_c(name = "2-4 kHz gain (dB)", option = "viridis", limits = lim_gain, na.value = "grey80") +
  labs(x = "Loudness cap (sones)", y = "Minimum insertion gain (dB)", subtitle = profile_names_map["a5"]) +
  theme_minimal()

p_a4_sii <- ggplot(feas_sub[feas_sub$Profile == "a4", ], aes(x = L_cap, y = vent_floor, fill = SII_smoothed_plot)) +
  geom_tile() +
  geom_vline(xintercept = norm_cap, linetype = "dashed", color = "grey20", linewidth = 0.8) +
  geom_vline(xintercept = unaided_a4, linetype = "dotted", color = "grey20", linewidth = 0.8) +
  geom_point(data = nal_pts[nal_pts$Profile == "a4", ], aes(x = L_cap, y = vent_floor), color = "red", shape = 4, size = 3, stroke = 1.5, inherit.aes = FALSE) +
  geom_label(data = nal_pts[nal_pts$Profile == "a4", ], aes(x = L_cap, y = vent_floor + 1.2, label = sprintf("%.3f", SII_smooth)), fill = "white", label.size = 0, color = "red", fontface = "bold", inherit.aes = FALSE) +
  scale_fill_viridis_c(name = "SII (desensitized, smoothed)", option = "viridis", limits = lim_sii, na.value = "grey80") +
  labs(x = "Loudness cap (sones)", y = "Minimum insertion gain (dB)") +
  theme_minimal()

p_a5_sii <- ggplot(feas_sub[feas_sub$Profile == "a5", ], aes(x = L_cap, y = vent_floor, fill = SII_smoothed_plot)) +
  geom_tile() +
  geom_vline(xintercept = norm_cap, linetype = "dashed", color = "grey20", linewidth = 0.8) +
  geom_vline(xintercept = unaided_a5, linetype = "dotted", color = "grey20", linewidth = 0.8) +
  geom_point(data = nal_pts[nal_pts$Profile == "a5", ], aes(x = L_cap, y = vent_floor), color = "red", shape = 4, size = 3, stroke = 1.5, inherit.aes = FALSE) +
  geom_label(data = nal_pts[nal_pts$Profile == "a5", ], aes(x = L_cap, y = vent_floor + 1.2, label = sprintf("%.3f", SII_smooth)), fill = "white", label.size = 0, color = "red", fontface = "bold", inherit.aes = FALSE) +
  scale_fill_viridis_c(name = "SII (desensitized, smoothed)", option = "viridis", limits = lim_sii, na.value = "grey80") +
  labs(x = "Loudness cap (sones)", y = "Minimum insertion gain (dB)") +
  theme_minimal()

figA <- (p_a4_gain | p_a5_gain) / (p_a4_sii | p_a5_sii) +
  plot_annotation(tag_levels = 'A') +
  plot_layout(guides = "collect")

ggsave(file.path(out_dir, "Fig_feasibility_A4_A5.png"), figA, width = 12, height = 10, dpi = 300, bg="white")
ggsave(file.path(out_dir, "Fig_feasibility_A4_A5.pdf"), figA, width = 12, height = 10, bg="white")


# ---------------------------------------------------------
# FIGURE B: Sensitivity
# ---------------------------------------------------------
sens_df <- read.csv(file.path(in_dir, "desens_sensitivity_diffs.csv"))
sens_df$ProfileName <- factor(profile_names_map[sens_df$Profile], levels = profile_names_map)

# Okabe-Ito palette mapped to the 7 profiles
okabe_ito <- c("a1"="#E69F00", "a2"="#56B4E9", "a3"="#009E73", 
               "a4"="#D55E00", "a5"="#0072B2", "a6"="#999999", "a7"="#CC79A7")
names(okabe_ito) <- profile_names_map[names(okabe_ito)]

shapes <- c(16, 17, 15, 3, 7, 8, 4)
linetypes <- c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash", "F8")

figB <- ggplot(sens_df, aes(x = Scale, y = diff_smoothed_s, color = ProfileName, shape = ProfileName, linetype = ProfileName)) +
  geom_hline(yintercept = 0, color = "black", linetype = "solid", linewidth = 0.5) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  scale_color_manual(name = "Profile", values = okabe_ito) +
  scale_shape_manual(name = "Profile", values = shapes) +
  scale_linetype_manual(name = "Profile", values = linetypes) +
  labs(x = "Desensitization scale (0 = none, 1 = full)", y = expression(Delta * "SII: -10 dB minus 0 dB minimum insertion gain")) +
  theme_minimal() +
  theme(legend.position = "right")

ggsave(file.path(out_dir, "Fig_desens_sensitivity.png"), figB, width = 8, height = 6, dpi = 300, bg="white")
ggsave(file.path(out_dir, "Fig_desens_sensitivity.pdf"), figB, width = 8, height = 6, bg="white")


# ---------------------------------------------------------
# Captions
# ---------------------------------------------------------
cap_text <- "Feasibility figure:
\"Optimal 65-dB SPL solutions for profiles A4 (moderate-to-severe
precipitous) and A5 (profound precipitous) as a function of the
loudness cap and the minimum insertion gain allowed at any frequency.
Top: mean 2-4 kHz insertion gain of the SII-optimal solution. Bottom:
desensitized SII (smoothed Johnson and Dillon penalty, the quantity maximized) of the same
solutions. Each tile is one optimization; minimum gains of 0, -5, -10
and -15 dB were computed. A 0-dB minimum corresponds to an open
fitting; negative values require an occluding fitting. The dashed line marks the
loudness of unaided speech for normal hearing; the dotted line
marks the loudness of unaided speech for the impaired ear. Grey
tiles: the cap is below what the constraint allows (for a 0-dB
minimum, below unaided loudness) and cannot be met. The
cross marks NAL-NL2's predicted loudness with no negative gain; its
label gives NAL-NL2's own value, whereas the tile beneath it shows the
optimal solution at that cap. Above about
9 sones the loudness constraint no longer binds, and from about
8 sones the minimum gain no longer changes the solution. Isolated
non-monotonic tiles reflect optimizer precision (about 0.01 SII).\"

Sensitivity figure:
\"Change in SII from allowing -10 dB rather than 0 dB minimum insertion
gain, at equal loudness (the cap was set to NAL-NL2's predicted
loudness for each profile, 65 dB SPL), as a function of the strength
of the hearing-loss desensitization penalty (0 = none, 1 = full
Johnson and Dillon). SII is the smoothed desensitized index at the
same scale used in optimization. A 0-dB minimum corresponds to an open
fitting and -10 dB requires an occluding fitting. Profiles A6 and A7
show no change and overlap at zero. Individual values carry optimizer
noise of about +/-0.01-0.02.\"
"
writeLines(cap_text, file.path(out_dir, "captions.txt"))

cat("Script finished.\n")
