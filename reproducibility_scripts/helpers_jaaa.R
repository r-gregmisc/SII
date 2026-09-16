tryCatch(pkgload::unload("SII"), error = function(e) NULL); devtools::load_all("/home/mark/Development/SII-github", reset = TRUE, quiet=TRUE)


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
    fs = 32000, N = 8192, 
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
