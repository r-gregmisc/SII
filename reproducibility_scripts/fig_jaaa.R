## fig_jaaa.R ----------------------------------------------------------------
## The two manuscript figures, drawn to JAAA's figure specification.
##
## JAAA requirements (Author Instructions, updated 2023):
##   - lettering must remain readable when the figure is reduced to one-column
##     width (2.75 in / 7 cm), at roughly the size of ordinary journal text
##   - at least 300 dpi; at that resolution a figure must be 5.75 in wide
##   - vector .eps preferred for figures containing text
##   - no colour unless essential
##   - legends go in the manuscript on a separate page, NOT inside the figure
##   - avoid closely spaced gridlines
##
## So both figures are drawn at 5.75 in wide with type large enough to survive
## reduction to 2.75 in (a factor of 0.48), carry no embedded caption, use only
## greys, and are written as .eps, .pdf and 600-dpi .tiff.
##
## Figure 1 is replotted as the fraction of the ceiling consumed rather than as
## stacked sones: that is the quantity the text reports, and a single panel
## stays legible at column width where three stacked-bar facets would not.
##
## Inputs:
##   reproducibility_scripts/output/bisgaard/budget_decomposition.csv
##     (from rerun_bisgaard_profiles.R; the ten Bisgaard et al. 2010 audiograms)
##   reproducibility_scripts/output/complete_objective/all_solutions.csv
##     (from rerun_complete_objective.R; objective = complete desensitized SII)
## Outputs:
##   figures/Figure1_Loudness_Budget.{eps,pdf,tiff,png}
##   figures/Figure2_Mechanism_Spectral.{eps,pdf,tiff,png}
##
## Read-only; no optimizer. Run from the repository root.
## -----------------------------------------------------------------------------

library(ggplot2)
suppressMessages(library(dplyr))
suppressMessages(library(tidyr))

out_dir <- "figures"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

## 5.75 in wide, with type sized to read at ~7-8 pt after reduction to 2.75 in.
W <- 5.75
BASE <- 16

save_all <- function(plot, stem, height) {
  ggsave(file.path(out_dir, paste0(stem, ".pdf")), plot,
         width = W, height = height, bg = "white")
  ggsave(file.path(out_dir, paste0(stem, ".eps")), plot,
         width = W, height = height, device = cairo_ps, bg = "white")
  ggsave(file.path(out_dir, paste0(stem, ".tiff")), plot,
         width = W, height = height, dpi = 600, compression = "lzw",
         bg = "white")
  ggsave(file.path(out_dir, paste0(stem, ".png")), plot,
         width = W, height = height, dpi = 300, bg = "white")
  cat("  wrote", stem, "(.pdf .eps .tiff .png)\n")
}

jaaa_theme <- theme_classic(base_size = BASE) +
  theme(axis.text = element_text(colour = "black", size = BASE - 2),
        axis.title = element_text(size = BASE),
        axis.line = element_line(linewidth = 0.6),
        axis.ticks = element_line(linewidth = 0.6),
        strip.background = element_blank(),
        strip.text = element_text(size = BASE - 1),
        legend.position = "top",
        legend.title = element_text(size = BASE - 2),
        legend.text = element_text(size = BASE - 2),
        legend.key.size = unit(0.9, "lines"),
        plot.margin = margin(6, 10, 6, 6))

## ==== Figure 1: fraction of the ceiling consumed ============================

cat("Figure 1\n")
b_csv <- "reproducibility_scripts/output/bisgaard/budget_decomposition.csv"
stopifnot(file.exists(b_csv))
b <- read.csv(b_csv, stringsAsFactors = FALSE) %>%
  dplyr::filter(Profile != "Normal") %>%
  dplyr::mutate(profile_f = factor(Profile, levels = c(paste0("N", 1:7), paste0("S", 1:3))),
                level_f = factor(Level, levels = c(50, 65, 80),
                                 labels = c("50", "65", "80")),
                pct = 100 * L0 / Lcap)

zero_lab <- b %>%
  dplyr::filter(pct < 0.05) %>%
  dplyr::mutate(x = as.numeric(profile_f) + (as.numeric(level_f) - 2) * 0.8 / 3)

g1 <- ggplot(b, aes(x = profile_f, y = pct, fill = level_f)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75,
           colour = "black", linewidth = 0.4) +
  ## Unamplified speech is inaudible to the model for some cells (0%); label
  ## them so a true zero is not mistaken for a missing value. Positions are
  ## computed directly: with three levels dodged over 0.8, bar centres sit at
  ## -0.8/3, 0 and +0.8/3 from each audiogram's tick.
  geom_text(data = zero_lab, aes(x = x, y = 1.5, label = "0"),
            inherit.aes = FALSE, vjust = 0, size = (BASE - 5) / .pt) +
  scale_fill_manual(name = "Input level (dB SPL)",
                    values = c("50" = "white", "65" = "grey65", "80" = "grey25")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(x = "Standard audiogram",
       y = "Ceiling consumed by\nunamplified speech (%)") +
  jaaa_theme

save_all(g1, "Figure1_Loudness_Budget", height = 4.0)

## ==== Figure 2: spectral reallocation ======================================
## 2 x 2 facets rather than 1 x 4, so each panel stays readable at column
## width. Individual audiograms are thinner grey lines; the mean is black.

cat("Figure 2\n")
## Audiogram-family solutions optimized on the complete desensitized SII,
## anchor on; where a pair was rerun with 40 restarts, the rerun is used.
s_csv <- "reproducibility_scripts/output/complete_objective/all_solutions.csv"
stopifnot(file.exists(s_csv))
d <- read.csv(s_csv, stringsAsFactors = FALSE) %>%
  dplyr::filter(set == "sweep", anchor == "on") %>%
  dplyr::group_by(profile, budget) %>%
  dplyr::filter(starts == max(starts)) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(audiogram = profile,
                edge  = as.numeric(sub("^e(\\d+)_s\\d+$", "\\1", profile)),
                slope = as.numeric(sub("^e\\d+_s(\\d+)$", "\\1", profile)),
                desens = 1, sones = sones_opt) %>%
  as.data.frame()
stopifnot(nrow(d) == 128)

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
gcols <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")
dcols <- paste0("d", hl_freqs)

pair <- d %>%
  dplyr::select(audiogram, edge, slope, desens, budget, floor, sones,
                dplyr::all_of(gcols)) %>%
  tidyr::pivot_wider(names_from = floor,
                     values_from = c(sones, dplyr::all_of(gcols)),
                     names_sep = "_f")
for (i in seq_along(gcols)) {
  pair[[dcols[i]]] <- pair[[paste0(gcols[i], "_f-10")]] -
                      pair[[paste0(gcols[i], "_f0")]]
}
pair$iso <- abs(pair$`sones_f-10` - pair$sones_f0) <= 0.001

long <- pair %>%
  dplyr::filter(iso, budget == 0.5) %>%
  dplyr::select(audiogram, edge, desens, dplyr::all_of(dcols)) %>%
  tidyr::pivot_longer(dplyr::all_of(dcols), names_to = "freq",
                      values_to = "d_gain") %>%
  dplyr::mutate(freq = as.numeric(sub("^d", "", freq)),
                edge_f = factor(edge, levels = c(1000, 1500, 2000, 3000),
                                labels = paste0("Edge ", c(1000, 1500, 2000, 3000), " Hz")))

mean_df <- long %>%
  dplyr::group_by(edge_f, freq) %>%
  dplyr::summarise(d_gain = mean(d_gain), .groups = "drop")

g2 <- ggplot(long, aes(x = freq, y = d_gain)) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.5) +
  geom_line(aes(group = interaction(audiogram, desens)),
            colour = "grey70", linewidth = 0.4) +
  geom_line(data = mean_df, colour = "black", linewidth = 1.3) +
  geom_point(data = mean_df, colour = "black", fill = "white",
             shape = 21, size = 2.6, stroke = 1) +
  scale_x_continuous(trans = "log10", breaks = c(250, 1000, 4000),
                     labels = c("0.25", "1", "4"),
                     minor_breaks = NULL) +
  facet_wrap(~ edge_f, nrow = 2) +
  labs(x = "Frequency (kHz)",
       y = "Change in insertion gain (dB)") +
  jaaa_theme +
  theme(panel.spacing = unit(1.1, "lines"))

save_all(g2, "Figure2_Mechanism_Spectral", height = 5.6)

cat("\nFigure 1 values (% of ceiling consumed):\n")
print(as.data.frame(
  b %>% dplyr::mutate(pct = round(pct, 1)) %>%
    tidyr::pivot_wider(names_from = Level, values_from = pct,
                       id_cols = Profile)))
cat("\nDone. Check legibility by viewing each PDF at 7 cm width.\n")
