# make_cases.R
# Writes identical test inputs for the AUDMOD C++ port and AMT 1.6.0 bramslow2004.
# Run from the package root:
#   Rscript reproducibility_scripts/audmod_validation/make_cases.R

devtools::load_all(quiet = TRUE)

fs <- 32000
N  <- 8192
base   <- "reproducibility_scripts/audmod_validation"
dir_in <- file.path(base, "in")
dir.create(dir_in, recursive = TRUE, showWarnings = FALSE)

amt_f <- c(125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500)
aud_f <- c(250, 500, 1000, 2000, 4000, 8000)
bin_f <- (1:(N / 2)) * fs / N

to13 <- function(hl6) approx(log10(aud_f), hl6, log10(amt_f), rule = 2)$y

tone <- function(f, dB) {
  P <- numeric(N / 2)
  P[round(f * N / fs)] <- 10^(dB / 10)
  P
}
flat_noise <- function(dB_per_Hz) rep(10^(dB_per_Hz / 10) * fs / N, N / 2)
ltass <- function(level) {
  L6 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) + (level - 65)
  L  <- approx(log10(aud_f), L6, log10(bin_f), rule = 2)$y
  lo <- bin_f < aud_f[1]
  hi <- bin_f > aud_f[6]
  L[lo] <- L6[1] - 24 * log2(aud_f[1] / bin_f[lo])
  L[hi] <- L6[6] - 24 * log2(bin_f[hi] / aud_f[6])
  10^(L / 10) * fs / N
}

nh     <- rep(0, 6)
flat40 <- rep(40, 6)

cases <- list(
  list(name = "tone1k60_NH",     P = tone(1000, 60), hl = nh),
  list(name = "tone1k60_flat40", P = tone(1000, 60), hl = flat40),
  list(name = "tone250_60_NH",   P = tone(250, 60),  hl = nh),
  list(name = "noise20_NH",      P = flat_noise(20), hl = nh),
  list(name = "noise20_flat40",  P = flat_noise(20), hl = flat40)
)
for (lvl in c(50, 65, 80)) {
  cases[[length(cases) + 1]] <- list(name = sprintf("ltass%d_NH", lvl),
                                     P = ltass(lvl), hl = nh)
  for (p in c("a1", "a2", "a3", "a4", "a5")) {
    cases[[length(cases) + 1]] <- list(name = sprintf("ltass%d_%s", lvl, p),
                                       P = ltass(lvl),
                                       hl = jd2011_targets[[p]]$threshold)
  }
}

numeric_rows <- matrix(NA_real_, nrow = length(cases), ncol = 27)
case_names   <- data.frame(id = seq_along(cases), name = NA_character_)

for (i in seq_along(cases)) {
  cs <- cases[[i]]
  stopifnot(length(cs$hl) == 6, length(cs$P) == N / 2, all(is.finite(cs$P)))
  writeLines(formatC(cs$P, digits = 17, format = "g"),
             file.path(dir_in, sprintf("spec_%d.csv", i)))
  numeric_rows[i, ] <- c(i, to13(cs$hl), rep(120, 13))
  case_names$name[i] <- cs$name
}

write.table(numeric_rows, file.path(dir_in, "cases_numeric.csv"),
            sep = ",", row.names = FALSE, col.names = FALSE)
write.csv(case_names, file.path(dir_in, "case_names.csv"), row.names = FALSE)

cat("Wrote", length(cases), "cases to", dir_in, "\n")
print(case_names, row.names = FALSE)
