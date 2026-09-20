load('data/critical.rda')
tryCatch(pkgload::unload("SII"), error = function(e) NULL); devtools::load_all(".", reset = TRUE, quiet=TRUE)

options(open_nl_maxit = 800)

build_dense_spectrum <- function(level, gain6, abg6) {
  hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
  input_speech <- ltass_65 + (level - 65)
  aided_spl <- input_speech + gain6 - abg6
  
  dense_f <- seq(10, 23990, by = 10)
  dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y
  dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
  dense_l[dense_f > hl_freqs[6]] <- aided_spl[6] - 24 * log2(dense_f[dense_f > hl_freqs[6]] / hl_freqs[6])
  
  list(freq = dense_f, level = dense_l)
}

loudness_of <- function(level, gain6, threshold6, abg6) {
  spec <- build_dense_spectrum(level, gain6, abg6)
  sn_htl <- pmax(0, threshold6 - abg6)
  hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  
  SII:::calculate_loudness_audmod(
    freq = spec$freq, 
    level_dB_per_Hz = spec$level,
    audiogram_freq = hl_freqs, 
    audiogram_HL = sn_htl,
    fs = 32000, N = 8192
  )
}

lcap <- function(level) {
  SII:::normal_speech_loudness(level)
}

write_run_metadata <- function(out_dir) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  hash <- tryCatch(system("git rev-parse HEAD", intern = TRUE), error = function(e) "unknown_commit")
  info <- capture.output(sessionInfo())
  writeLines(c(paste("Git Commit:", hash), "", info), file.path(out_dir, "metadata.txt"))
}

# Constructs the EXACT speech spectrum open_nl() uses internally
build_opennl_speech <- function(freq, eval_level) {
  fi <- critical$fi
  normal_speech_base <- approx(x = log10(fi), y = critical$normal, xout = log10(freq), rule = 2)$y
  overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
  normal_speech_base + (eval_level - overall_normal)
}

build_target <- function(freq, speech_spec, threshold, loss, gain_vec, eval_level = 65) {
  fi <- critical$fi
  
  # Based on open_nl.R
  mpo_base <- SII:::calculate_nal_sspl90(threshold, gain_vec, NULL, loss, freq)
  
  temp_tgt <- list(
    freq = fi,
    gain = approx(log10(freq), gain_vec, log10(fi), rule=2)$y,
    mpo = approx(log10(freq), mpo_base, log10(fi), rule=2)$y,
    speech = approx(log10(freq), speech_spec, log10(fi), rule=2)$y,
    threshold = approx(log10(freq), threshold, log10(fi), rule=2)$y,
    loss = approx(log10(freq), if(is.null(loss)) rep(0, length(freq)) else loss, log10(fi), rule=2)$y,
    module = "standard",
    overall_level = eval_level,
    orig_freq = freq, orig_speech = speech_spec, orig_threshold = threshold, orig_loss = loss
  )
  class(temp_tgt) <- "prescription_target"
  return(temp_tgt)
}

report_sii <- function(target, desensitization, nal_ldf = FALSE, desensitization_scale = 1.0) {
  SII::sii(speech = target$orig_speech, noise = rep(-50, length(target$orig_freq)),
      threshold = target$orig_threshold, loss = target$orig_loss, freq = target$orig_freq,
      prescription = target, interpolate = TRUE,
      nal_ldf = nal_ldf, desensitization = desensitization,
      desensitization_scale = desensitization_scale)$sii
}
