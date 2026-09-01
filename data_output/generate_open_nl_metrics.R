# generate_open_nl_metrics.R
# Computes ANSI SII, Johnson2011_complete SII, and Bramslow2004 Sone levels
# for NAL-NL2 and Open-NL prescriptions across audiograms A1-A7 at 65 dB SPL.
#
# Loudness is computed using the SAME signal pipeline as generate_amt_benchmark.R
# (and thus the Octave bramslow2004 AMT benchmark), so results are directly comparable.
#
# LTASS values at 65 dB SPL (250, 500, 1000, 2000, 4000, 8000 Hz):
#   c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) dB SPL per band

devtools::load_all(".")
# Force load our patched files to bypass devtools caching
source("R/sii.R")
source("R/nalr.R")
source("R/open_nl.R")
source("R/benchmark_targets.R")
load("data/critical.rda")

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
ltass_65  <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)  # LTASS at 65 dB SPL

# Helper: compute Bramslow2004 sones using the same pipeline as generate_amt_benchmark.R
calc_bramslow_sones <- function(gain_tgt, threshold, loss, freqs = hl_freqs, target_level = 65) {
  input_speech <- ltass_65 + (target_level - 65)
  aided_spl    <- input_speech + gain_tgt - loss

  # Step 1: Compute overall SPL on 0.5 Hz grid for power normalization
  f_half <- seq(0, 24000, by = 0.5); f_half[1] <- 1
  li <- approx(log10(freqs), aided_spl, log10(f_half), rule = 2)$y
  li[f_half < freqs[1]]          <- aided_spl[1]          - 24 * log2(freqs[1]        / pmax(f_half[f_half < freqs[1]], 1))
  li[f_half > freqs[length(freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[f_half > freqs[length(freqs)]] / freqs[length(freqs)])
  overall <- 10 * log10(sum(10^(li / 10)) * 0.5)

  # Step 2: Dense 10 Hz grid, normalized to match overall SPL
  dense_f <- seq(10, 23990, by = 10)
  dense_l <- approx(log10(freqs), aided_spl, log10(dense_f), rule = 2)$y
  dense_l[dense_f < freqs[1]]             <- aided_spl[1]             - 24 * log2(freqs[1]        / dense_f[dense_f < freqs[1]])
  dense_l[dense_f > freqs[length(freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[dense_f > freqs[length(freqs)]] / freqs[length(freqs)])
  current_spl <- 10 * log10(sum(10^(dense_l / 10) * 10))
  dense_l     <- dense_l + (overall - current_spl)

  # Step 3: OHC/IHC split of sensorineural loss (Bramslow2004 / Moore & Glasberg convention)
  sn_loss  <- pmax(threshold - loss, 0)
  ohc_loss <- pmin(sn_loss, 65)
  ihc_loss <- pmax(sn_loss - 65, 0)

  # Step 4: Call RCPP Bramslow2004 loudness model (validated engine — do NOT change)
  res <- tryCatch(
    calculate_loudness_cpp(
      inputF     = dense_f,
      inputLdB   = dense_l,
      HLcf       = freqs,
      HLohcdB0   = ohc_loss,
      HLihcdB0   = ihc_loss
    ),
    error = function(e) NULL
  )
  if (is.null(res)) return(NA)
  return(res$Ldn)
}

# ── Audiogram definitions ─────────────────────────────────────────────────────
# Pull directly from jd2011_targets to avoid duplicate definitions
# threshold: at 6 standard audiometric frequencies (250-8000 Hz)
# loss:      ABG (conductive component); 0 if not present (pure sensorineural)
prof_keys  <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
prof_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

# ── Main loop ────────────────────────────────────────────────────────────────
f_21   <- critical$fi
overall_normal <- 62.35

results <- data.frame()

for (i in seq_along(prof_keys)) {
  p         <- prof_keys[i]
  prof_name <- prof_names[i]
  tgt       <- jd2011_targets[[p]]
  threshold <- tgt$threshold                                    # 6 standard freqs
  loss      <- if (!is.null(tgt$loss)) tgt$loss else rep(0, 6) # ABG; 0 for pure SN

  cat(sprintf("Processing %s...\n", prof_name))

  # ── NAL-NL2 ──────────────────────────────────────────────────────────────
  nal_gain  <- get_nalnl2_v2_target(p, "NAL-NL2", hl_freqs, 65)

  # Interpolate to 21-band grid for SII
  htl_21  <- approx(log10(hl_freqs), threshold, log10(f_21), rule = 2)$y
  loss_21 <- approx(log10(hl_freqs), loss,      log10(f_21), rule = 2)$y
  nal_21  <- approx(log10(hl_freqs), nal_gain,  log10(f_21), rule = 2)$y

  speech_65 <- critical$normal + (65 - overall_normal)
  nal_ansi    <- sii(speech = speech_65, threshold = htl_21, loss = loss_21, freq = f_21,
                     custom_gain = nal_21, desensitization = "none")
  nal_johnson <- sii(speech = speech_65, threshold = htl_21, loss = loss_21, freq = f_21,
                     custom_gain = nal_21, desensitization = "johnson2011_complete")
  nal_sones   <- calc_bramslow_sones(nal_gain, threshold, loss)

  results <- rbind(results, data.frame(
    Audiogram = prof_name, Formula = "NAL-NL2",
    ANSI_SII = nal_ansi$sii, Johnson2011_Complete_SII = nal_johnson$sii,
    Bramslow2004_Sones = nal_sones
  ))
  cat(sprintf("  NAL-NL2: SII=%.3f, Sones=%.2f\n", nal_ansi$sii, nal_sones))

  # ── Open-NL ──────────────────────────────────────────────────────────────
  op_res   <- open_nl(speech = 65, threshold = threshold, freq = hl_freqs, loss = loss)
  op_gain  <- op_res$gain
  op_21    <- approx(log10(hl_freqs), op_gain, log10(f_21), rule = 2)$y

  op_ansi    <- sii(speech = speech_65, threshold = htl_21, loss = loss_21, freq = f_21,
                    custom_gain = op_21, desensitization = "none")
  op_johnson <- sii(speech = speech_65, threshold = htl_21, loss = loss_21, freq = f_21,
                    custom_gain = op_21, desensitization = "johnson2011_complete")
  op_sones   <- calc_bramslow_sones(op_gain, threshold, loss)
  
  # DEBUG: Print gain values and cochlear SPL for A6 and A7
  if (prof_name %in% c("A6", "A7")) {
    cat(sprintf("  DEBUG %s Open-NL gain: %s\n", prof_name, paste(round(op_gain, 2), collapse=", ")))
    cat(sprintf("  DEBUG %s NAL-NL2 gain: %s\n", prof_name, paste(round(nal_gain, 2), collapse=", ")))
    cochlear_op  <- ltass_65 + op_gain - loss
    cochlear_nal <- ltass_65 + nal_gain - loss
    cat(sprintf("  DEBUG %s Open-NL cochlear SPL: %s\n", prof_name, paste(round(cochlear_op, 2), collapse=", ")))
    cat(sprintf("  DEBUG %s NAL-NL2 cochlear SPL: %s\n", prof_name, paste(round(cochlear_nal, 2), collapse=", ")))
  }

  results <- rbind(results, data.frame(
    Audiogram = prof_name, Formula = "Open-NL",
    ANSI_SII = op_ansi$sii, Johnson2011_Complete_SII = op_johnson$sii,
    Bramslow2004_Sones = op_sones
  ))
  cat(sprintf("  Open-NL: SII=%.3f, Sones=%.2f\n", op_ansi$sii, op_sones))
}

# ── Save CSV ─────────────────────────────────────────────────────────────────
output_file <- "data_output/open_nl_prescription_metrics_A1_A7.csv"
write.csv(results, output_file, row.names = FALSE)
cat(sprintf("\nResults saved to: %s\n\n", output_file))

# ── Print and Save markdown table ────────────────────────────────────────────
output_log <- "reviewer_archive/metrics_output_log.txt"
if (!dir.exists("reviewer_archive")) dir.create("reviewer_archive")

print_table <- function() {
  cat(sprintf("%-5s | %-8s | %-9s | %-25s | %-20s\n",
              "Audio", "Formula", "ANSI SII", "Johnson2011 Complete SII", "Bramslow2004 Sones"))
  cat(paste(rep("-", 80), collapse=""), "\n")
  for (i in seq_len(nrow(results))) {
    r <- results[i, ]
    cat(sprintf("%-5s | %-8s | %-9.3f | %-25.3f | %-20.2f\n",
                r$Audiogram, r$Formula, r$ANSI_SII,
                r$Johnson2011_Complete_SII, r$Bramslow2004_Sones))
  }
}

# Print to console
print_table()

# Save to log file
sink(output_log)
print_table()
sink()

cat(sprintf("\nConsole output saved to: %s\n", output_log))
