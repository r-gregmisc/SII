## fig_mechanism.R -----------------------------------------------------------
## Where does the budget go when the minimum-gain floor is relaxed?
##
## The SII difference says only that relaxing the floor improves audibility.
## The gain vectors say where the capacity comes from and where it goes.
##
## All figures are greyscale-safe: groups are distinguished by linetype and
## point shape, never by colour alone, so they survive black-and-white print.
##
## Input:  reproducibility_scripts/output/isoloudness/isoloudness_starts20_naldf_off.csv
## Output: reproducibility_scripts/output/jaaa_audmod/mechanism_*.png/.pdf
##
## Read-only on the data; no optimizer. Run from the repository root.
## dplyr verbs are namespace-qualified, since other packages mask summarise().
## -----------------------------------------------------------------------------

library(ggplot2)
suppressMessages(library(dplyr))
suppressMessages(library(tidyr))

in_csv  <- "reproducibility_scripts/output/isoloudness/isoloudness_starts20_naldf_off.csv"
out_dir <- "reproducibility_scripts/output/jaaa_audmod"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

stopifnot(file.exists(in_csv))
d <- read.csv(in_csv, stringsAsFactors = FALSE)
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
gcols <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")
dcols <- paste0("d", hl_freqs)

cat(sprintf("%d rows | starts %s | nal_ldf %s\n",
            nrow(d), paste(unique(d$starts), collapse = ","),
            paste(unique(d$nal_ldf), collapse = ",")))

## ---- pair the two floors within each cell --------------------------------

pair <- d %>%
  dplyr::select(audiogram, edge, slope, desens, budget, floor, sii, sones,
                dplyr::all_of(gcols)) %>%
  tidyr::pivot_wider(names_from = floor,
                     values_from = c(sii, sones, dplyr::all_of(gcols)),
                     names_sep = "_f")

for (i in seq_along(gcols)) {
  pair[[dcols[i]]] <- pair[[paste0(gcols[i], "_f-10")]] -
                      pair[[paste0(gcols[i], "_f0")]]
}
pair$d_sii   <- pair$`sii_f-10`   - pair$sii_f0
pair$d_sones <- pair$`sones_f-10` - pair$sones_f0
pair$iso     <- abs(pair$d_sones) <= 0.001

res_limit <- max(abs(pair$d_sii[pair$iso & pair$d_sii < 0]))
cat(sprintf("resolution limit (largest negative at iso-loudness): %.4f\n", res_limit))
cat(sprintf("iso-loudness cells: %d of %d\n", sum(pair$iso), nrow(pair)))

edge_lab   <- function(x) factor(x, levels = c(1000, 1500, 2000, 3000),
                                 labels = paste0(c(1000, 1500, 2000, 3000), " Hz edge"))
budget_lab <- function(x) factor(x, levels = c(0.5, 1, 2, 3),
                                 labels = paste0(c(0.5, 1, 2, 3), " sones"))

base_theme <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold", size = 10),
        legend.position = "bottom",
        plot.caption = element_text(hjust = 0, size = 8, colour = "grey30"))

## ---- long form ------------------------------------------------------------
## Pivot the d-columns by name: starts_with("d") would also catch `desens`.

long <- pair %>%
  dplyr::filter(iso) %>%
  dplyr::select(audiogram, edge, slope, desens, budget, dplyr::all_of(dcols)) %>%
  tidyr::pivot_longer(dplyr::all_of(dcols), names_to = "freq", values_to = "d_gain") %>%
  dplyr::mutate(freq = as.numeric(sub("^d", "", freq)),
                edge_f = edge_lab(edge),
                budget_f = budget_lab(budget))

## ==== Figure A: spectral reallocation, tight budget ========================
## The desensitization scales overlap almost completely, so the main version
## collapses across them and the by-scale version is kept as supplementary.

figA_dat <- long %>% dplyr::filter(budget == 0.5)

figA_mean <- figA_dat %>%
  dplyr::group_by(edge_f, freq) %>%
  dplyr::summarise(d_gain = mean(d_gain), n = dplyr::n(), .groups = "drop")

gA <- ggplot(figA_dat, aes(x = freq, y = d_gain)) +
  geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.4) +
  geom_line(aes(group = interaction(audiogram, desens)),
            colour = "grey80", linewidth = 0.28) +
  geom_line(data = figA_mean, colour = "black", linewidth = 0.95) +
  geom_point(data = figA_mean, colour = "black", size = 2, shape = 21,
             fill = "white", stroke = 0.9) +
  scale_x_continuous(trans = "log10", breaks = hl_freqs,
                     labels = c("250", "500", "1k", "2k", "4k", "8k")) +
  facet_wrap(~ edge_f, nrow = 1) +
  labs(x = "Frequency (Hz)",
       y = "Change in prescribed gain (dB)",
       caption = paste0(
         "Change when the minimum-gain floor is relaxed from 0 dB to -10 dB, at a 0.5-sone budget. ",
         "Grey lines: individual audiograms (4 slopes x 3 desensitization scales). Black: mean.\n",
         "Negative values are gain given up; positive values are gain gained. ",
         "Paired solutions are at matched loudness, so the areas trade off against one another.")) +
  base_theme

ggsave(file.path(out_dir, "mechanism_spectral.png"), gA,
       width = 11, height = 4.6, dpi = 300, bg = "white")
ggsave(file.path(out_dir, "mechanism_spectral.pdf"), gA,
       width = 11, height = 4.6, bg = "white")

## Supplementary: the same, split by desensitization scale. Linetype + shape,
## no colour, so the near-total overlap is still readable in print.

figA_bydes <- figA_dat %>%
  dplyr::group_by(edge_f, desens, freq) %>%
  dplyr::summarise(d_gain = mean(d_gain), .groups = "drop") %>%
  dplyr::mutate(ds = factor(desens, levels = c(0, 0.5, 1)))

gA2 <- ggplot(figA_bydes, aes(x = freq, y = d_gain, linetype = ds, shape = ds)) +
  geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.4) +
  geom_line(colour = "grey20", linewidth = 0.7) +
  geom_point(colour = "grey20", fill = "white", size = 2, stroke = 0.8) +
  scale_x_continuous(trans = "log10", breaks = hl_freqs,
                     labels = c("250", "500", "1k", "2k", "4k", "8k")) +
  scale_linetype_manual(name = "Desensitization scale",
                        values = c("solid", "longdash", "dotted")) +
  scale_shape_manual(name = "Desensitization scale", values = c(21, 24, 22)) +
  facet_wrap(~ edge_f, nrow = 1) +
  labs(x = "Frequency (Hz)", y = "Change in prescribed gain (dB)",
       caption = "The spectral pattern is essentially invariant to the desensitization scale, though the resulting SII change is not.") +
  base_theme

ggsave(file.path(out_dir, "mechanism_spectral_bydesens.png"), gA2,
       width = 11, height = 4.6, dpi = 300, bg = "white")
ggsave(file.path(out_dir, "mechanism_spectral_bydesens.pdf"), gA2,
       width = 11, height = 4.6, bg = "white")

## ==== Figure B: source and destination =====================================

figB <- pair %>%
  dplyr::filter(iso, budget == 0.5) %>%
  dplyr::mutate(low  = (d250 + d500 + d1000) / 3,
                mid  = (d2000 + d4000) / 2,
                high = d8000) %>%
  dplyr::select(audiogram, edge, slope, desens, low, mid, high) %>%
  tidyr::pivot_longer(c(low, mid, high), names_to = "region", values_to = "d_gain") %>%
  dplyr::mutate(region = factor(region, levels = c("low", "mid", "high"),
                                labels = c("250-1000 Hz", "2-4 kHz", "8 kHz")),
                edge_f = edge_lab(edge))

gB <- ggplot(figB, aes(x = region, y = d_gain)) +
  geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.4) +
  geom_boxplot(fill = "grey92", colour = "grey25", outlier.shape = NA,
               linewidth = 0.35, width = 0.6) +
  geom_jitter(width = 0.12, height = 0, size = 1.1, alpha = 0.6,
              colour = "grey15") +
  facet_wrap(~ edge_f, nrow = 1) +
  labs(x = NULL, y = "Change in prescribed gain (dB)",
       caption = "Capacity is drawn from both the low frequencies and 8 kHz, and spent at 2-4 kHz. Points are individual cells.") +
  base_theme +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

ggsave(file.path(out_dir, "mechanism_regions.png"), gB,
       width = 10, height = 4.2, dpi = 300, bg = "white")
ggsave(file.path(out_dir, "mechanism_regions.pdf"), gB,
       width = 10, height = 4.2, bg = "white")

## ==== Figure C: effect size against the resolution limit ===================
## Individual cells, not means: with 1-4 iso-loudness cells per edge/budget
## point, a mean would conceal how thin some of them are.

figC <- pair %>%
  dplyr::filter(iso) %>%
  dplyr::mutate(budget_f = budget_lab(budget),
                slope_f = factor(slope, levels = c(20, 30, 40, 50)))

gC <- ggplot(figC, aes(x = factor(edge), y = d_sii)) +
  annotate("rect", xmin = -Inf, xmax = Inf, ymin = -res_limit, ymax = res_limit,
           fill = "grey88") +
  geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.4) +
  geom_point(aes(shape = slope_f), position = position_jitter(width = 0.14, height = 0),
             size = 1.9, colour = "grey15", fill = "white", stroke = 0.7) +
  scale_shape_manual(name = "Slope (dB/octave)", values = c(21, 24, 22, 23)) +
  facet_wrap(~ budget_f, nrow = 1) +
  labs(x = "Audible edge frequency (Hz)",
       y = "SII change, -10 dB minus 0 dB floor",
       caption = sprintf(paste0(
         "Each point is one audiogram at one desensitization scale, restricted to cells at matched loudness. ",
         "Shaded band: optimizer resolution limit (+/- %.4f),\nthe largest negative excursion at matched loudness. ",
         "A negative change is impossible in a genuine comparison, so such excursions bound the precision of the solver."),
         res_limit)) +
  base_theme

ggsave(file.path(out_dir, "mechanism_effect_vs_noise.png"), gC,
       width = 11, height = 4.6, dpi = 300, bg = "white")
ggsave(file.path(out_dir, "mechanism_effect_vs_noise.pdf"), gC,
       width = 11, height = 4.6, bg = "white")

## ---- numbers for the captions --------------------------------------------

cat("\nFigure A, mean change in prescribed gain at budget 0.5 (dB), all scales:\n")
print(as.data.frame(
  figA_mean %>%
    dplyr::mutate(d_gain = round(d_gain, 2)) %>%
    tidyr::pivot_wider(names_from = freq, values_from = d_gain, id_cols = edge_f)))

cat("\nCells behind each Figure A point:\n")
print(as.data.frame(
  figA_mean %>% tidyr::pivot_wider(names_from = freq, values_from = n,
                                   id_cols = edge_f)))

cat("\nFigure C, cells per edge x budget:\n")
print(with(figC, table(edge, budget_f)))

cat("\nFigures written to", out_dir, "\n")
