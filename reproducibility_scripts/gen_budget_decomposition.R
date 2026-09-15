#!/usr/bin/env Rscript

pkg_root <- "/home/mark/Development/SII-github"
tryCatch(pkgload::unload("SII"), error = function(e) NULL)
devtools::load_all(pkg_root, reset = TRUE, quiet=TRUE)

source(file.path(pkg_root, "R/sii.R"), local = FALSE)
source(file.path(pkg_root, "R/nalr.R"), local = FALSE)
source(file.path(pkg_root, "R/open_nl.R"), local = FALSE)
load(file.path(pkg_root, "data/critical.rda"))

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1 (Mild)", "A2 (Rev Slope)", "A3 (Mod Sloping)", "A4 (Mod-Severe)", "A5 (Profound)", "A6 (Mixed)", "A7 (Conductive)")

# From open_nl.R logic
get_lcap <- function(htl_sn, eval_level) {
  pta_sn <- mean(htl_sn[2:4])
  pta_knots <- c(0, 30, 50, 70, 90)
  if (eval_level < 65) {
    cap_knots <- c(1.5, 1.0, 0.8, 1.2, 1.2)
  } else if (eval_level > 65) {
    cap_knots <- c(20.0, 12.0, 10.0, 15.0, 14.0)
  } else {
    cap_knots <- c(7.0, 4.5, 4.0, 6.5, 6.0)
  }
  approx(x = pta_knots, y = cap_knots, xout = pta_sn, rule = 2)$y
}

# Helper to calculate loudness using SII::calculate_loudness_cpp
calc_loudness <- function(gain_tgt, threshold, loss, target_level) {
  ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
  if (length(gain_tgt) != 6) {
      gain_tgt <- approx(log10(hl_freqs), gain_tgt, log10(hl_freqs), rule=2)$y
  }

  input_speech <- ltass_65 + (target_level - 65)
  aided_spl <- input_speech + gain_tgt - loss
  
  f_half <- seq(0, 24000, by = 0.5); f_half[1] <- 1
  li <- approx(log10(hl_freqs), aided_spl, log10(f_half), rule = 2)$y
  li[f_half < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / pmax(f_half[f_half < hl_freqs[1]], 1))
  li[f_half > hl_freqs[length(hl_freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[f_half > hl_freqs[length(hl_freqs)]] / hl_freqs[length(hl_freqs)])
  overall <- 10 * log10(sum(10^(li/10)) * 0.5)
  
  dense_f <- seq(10, 23990, by = 10)
  dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y
  dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
  dense_l[dense_f > hl_freqs[length(hl_freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[dense_f > hl_freqs[length(hl_freqs)]] / hl_freqs[length(hl_freqs)])
  current_spl <- 10 * log10(sum(10^(dense_l/10) * 10))
  dense_l <- dense_l + (overall - current_spl)
  
  sn_loss <- pmax(threshold - loss, 0)
  
  res <- tryCatch({
    calculate_loudness_cpp(inputF = dense_f, inputLdB = dense_l, HLcf = hl_freqs, HLdB = sn_loss, NoChan = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0)
  }, error = function(e) { NULL })
  
  return(res)
}

# Normative Caps (Normal Hearing Loudness for LTASS at 50, 65, 80 dB SPL)
# Calculated using the C++ Moore and Glasberg model
caps <- c(1.21, 7.00, 20.52)
levels <- c(50, 65, 80)

cat("Budget Decomposition (Unamplified Speech vs Normative Loudness Cap)\n")
cat("=================================================================\n\n")

cat("| Profile | Description | L0 (50 dB) | L_cap (50 dB) | L0 (65 dB) | L_cap (65 dB) | L0 (80 dB) | L_cap (80 dB) |\n")
cat("|:---|:---|:---|:---|:---|:---|:---|:---|\n")

for (i in 1:length(profiles)) {
  p <- profiles[i]
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  l0_50 <- calc_loudness(rep(0, 6), htl, loss, 50)$Ldn
  l0_65 <- calc_loudness(rep(0, 6), htl, loss, 65)$Ldn
  l0_80 <- calc_loudness(rep(0, 6), htl, loss, 80)$Ldn
  
  # Ensure 0 is handled if the model predicts basically no loudness
  if (is.null(l0_50)) l0_50 <- 0
  if (is.null(l0_65)) l0_65 <- 0
  if (is.null(l0_80)) l0_80 <- 0
  
  cat(sprintf("| %s | %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n", 
              toupper(p), profile_names[i], 
              l0_50, caps[1], 
              l0_65, caps[2], 
              l0_80, caps[3]))
}
cat("\n")

