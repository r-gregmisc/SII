## check_outlier_and_noise.R -------------------------------------------------
## Two questions about the mechanism figure and the resolution limit:
##
##   A  Which cell produces the -19 dB excursion at 8 kHz in the edge-1000
##      panel, and is it a real solution or an artefact of a cell that never
##      reached its cap?
##
##   B  What does the noise floor actually look like? The figure quotes the
##      single largest negative excursion at matched loudness (0.0074). That is
##      the conservative bound, but it is one number from one cell; the shape of
##      the whole distribution decides whether it is representative or extreme.
##
## Read-only. Run from the repository root.
## -----------------------------------------------------------------------------

suppressMessages(library(dplyr))
suppressMessages(library(tidyr))

in_csv <- "reproducibility_scripts/output/isoloudness/isoloudness_starts20_naldf_off.csv"
stopifnot(file.exists(in_csv))
d <- read.csv(in_csv, stringsAsFactors = FALSE)

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
gcols <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")
dcols <- paste0("d", hl_freqs)

pair <- d %>%
  dplyr::select(audiogram, edge, slope, desens, budget, floor, sii, sones, cap,
                n_neg, neg_bands, dplyr::all_of(gcols)) %>%
  tidyr::pivot_wider(names_from = floor,
                     values_from = c(sii, sones, cap, n_neg, neg_bands,
                                     dplyr::all_of(gcols)),
                     names_sep = "_f")

for (i in seq_along(gcols)) {
  pair[[dcols[i]]] <- pair[[paste0(gcols[i], "_f-10")]] -
                      pair[[paste0(gcols[i], "_f0")]]
}
pair$d_sii    <- pair$`sii_f-10`   - pair$sii_f0
pair$d_sones  <- pair$`sones_f-10` - pair$sones_f0
pair$iso      <- abs(pair$d_sones) <= 0.001
## how far each solution sat below its own cap
pair$slack_0  <- pair$cap_f0     - pair$sones_f0
pair$slack_10 <- pair$`cap_f-10` - pair$`sones_f-10`

cat(sprintf("%d paired cells, %d at matched loudness\n\n", nrow(pair), sum(pair$iso)))

## ==== PART A: the 8 kHz excursion ==========================================

cat("==== PART A: large 8 kHz changes at budget 0.5 ====\n\n")

a <- pair %>%
  dplyr::filter(budget == 0.5, iso) %>%
  dplyr::arrange(d8000) %>%
  dplyr::select(audiogram, edge, slope, desens, d8000, d2000, d4000,
                g8000_f0, `g8000_f-10`, slack_0, slack_10, d_sii,
                `neg_bands_f-10`)

cat("Ten most negative 8 kHz changes:\n")
print(as.data.frame(head(a, 10)), row.names = FALSE, digits = 4)

cat("\nThe cell driving the axis range (most negative overall):\n")
worst <- pair %>% dplyr::filter(budget == 0.5) %>%
  dplyr::slice_min(d8000, n = 1)
print(as.data.frame(worst %>% dplyr::select(
  audiogram, edge, slope, desens, budget, iso,
  sones_f0, `sones_f-10`, cap_f0, slack_0, slack_10,
  g8000_f0, `g8000_f-10`, d8000, d_sii)), row.names = FALSE, digits = 4)

cat("\nIts full gain vectors (dB):\n")
gv <- rbind(
  `floor 0`   = unlist(worst[paste0(gcols, "_f0")]),
  `floor -10` = unlist(worst[paste0(gcols, "_f-10")]))
colnames(gv) <- paste0(hl_freqs, "Hz")
print(round(gv, 2))

cat("\nIs a large negative d8000 associated with a cell that missed its cap?\n")
b05 <- pair %>% dplyr::filter(budget == 0.5)
cat(sprintf("  correlation(d8000, slack at floor -10): %+.3f\n",
            cor(b05$d8000, b05$slack_10)))
cat(sprintf("  mean slack where d8000 < -5 : %.4f sones (n = %d)\n",
            mean(b05$slack_10[b05$d8000 < -5]), sum(b05$d8000 < -5)))
cat(sprintf("  mean slack where d8000 >= -5: %.4f sones (n = %d)\n",
            mean(b05$slack_10[b05$d8000 >= -5]), sum(b05$d8000 >= -5)))

cat("\nd8000 by edge at budget 0.5 (iso-loudness cells only):\n")
print(b05 %>% dplyr::filter(iso) %>% dplyr::group_by(edge) %>%
        dplyr::summarise(n = dplyr::n(),
                         min = round(min(d8000), 2),
                         median = round(median(d8000), 2),
                         max = round(max(d8000), 2), .groups = "drop") %>%
        as.data.frame(), row.names = FALSE)

## ==== PART B: the noise floor ==============================================
## A negative d_SII at matched loudness is impossible: the 0 dB feasible set is
## contained in the -10 dB set. Every such value is therefore optimizer noise,
## and the distribution of their magnitudes is the precision of the solver.

cat("\n\n==== PART B: distribution of impossible (negative) differences ====\n\n")

neg <- pair %>% dplyr::filter(iso, d_sii < 0) %>% dplyr::mutate(mag = abs(d_sii))

cat(sprintf("%d negative cells out of %d at matched loudness (%.0f%%)\n\n",
            nrow(neg), sum(pair$iso), 100 * nrow(neg) / sum(pair$iso)))

cat("Magnitude of the excursions:\n")
print(round(quantile(neg$mag, c(0.5, 0.75, 0.9, 0.95, 0.99, 1)), 5))
cat(sprintf("\n  mean   %.5f\n  median %.5f\n  max    %.5f\n",
            mean(neg$mag), median(neg$mag), max(neg$mag)))

cat("\nHow many exceed each candidate threshold:\n")
for (t in c(0.001, 0.002, 0.005, 0.007)) {
  cat(sprintf("  > %.3f : %2d of %d (%.0f%%)\n", t, sum(neg$mag > t),
              nrow(neg), 100 * sum(neg$mag > t) / nrow(neg)))
}

cat("\nThe five largest, with context:\n")
print(as.data.frame(
  neg %>% dplyr::arrange(dplyr::desc(mag)) %>%
    dplyr::select(audiogram, edge, slope, desens, budget, d_sii, d_sones,
                  slack_0, slack_10, `n_neg_f-10`) %>%
    head(5)), row.names = FALSE, digits = 4)

cat("\nAre the large excursions concentrated anywhere?\n")
cat("\n  by budget:\n")
print(neg %>% dplyr::group_by(budget) %>%
        dplyr::summarise(n = dplyr::n(), max = round(max(mag), 5),
                         median = round(median(mag), 5), .groups = "drop") %>%
        as.data.frame(), row.names = FALSE)
cat("\n  by edge:\n")
print(neg %>% dplyr::group_by(edge) %>%
        dplyr::summarise(n = dplyr::n(), max = round(max(mag), 5),
                         median = round(median(mag), 5), .groups = "drop") %>%
        as.data.frame(), row.names = FALSE)

cat("\nIf the largest excursions cluster at loose budgets or high edges, a\n")
cat("limit computed from the regime the paper actually reports (tight budgets,\n")
cat("low edges) would be both smaller and more relevant:\n\n")
tight <- neg %>% dplyr::filter(budget <= 1)
if (nrow(tight)) {
  cat(sprintf("  budgets 0.5 and 1 only: n = %d, max = %.5f, 95th = %.5f\n",
              nrow(tight), max(tight$mag), quantile(tight$mag, 0.95)))
}
low <- neg %>% dplyr::filter(budget <= 1, edge <= 1500)
if (nrow(low)) {
  cat(sprintf("  budgets <= 1 and edge <= 1500: n = %d, max = %.5f\n",
              nrow(low), max(low$mag)))
} else {
  cat("  budgets <= 1 and edge <= 1500: no negative cells at all\n")
}

cat("\ndone\n")
