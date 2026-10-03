#' @noRd
normal_loudness_cache <- new.env(parent = emptyenv())

normal_speech_loudness <- function(level) {
  cache_key <- as.character(level)
  if (exists(cache_key, envir = normal_loudness_cache)) {
    return(get(cache_key, envir = normal_loudness_cache))
  }
  
  hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
  input_speech <- ltass_65 + (level - 65)
  
  dense_f <- seq(10, 23990, by = 10)
  dense_l <- approx(log10(hl_freqs), input_speech, log10(dense_f), rule = 2)$y
  dense_l[dense_f < hl_freqs[1]] <- input_speech[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
  dense_l[dense_f > hl_freqs[6]] <- input_speech[6] - 24 * log2(dense_f[dense_f > hl_freqs[6]] / hl_freqs[6])
  
  ref <- audmod_reference_cpp(fs = 32000, N = 8192, AGLoss_HL = rep(0, 13), AG_UCL_HL = rep(120, 13))
  
  res <- calculate_loudness_audmod(
    freq = dense_f, level_dB_per_Hz = dense_l,
    audiogram_freq = hl_freqs, audiogram_HL = rep(0, 6),
    fs = 32000, N = 8192, ref = ref
  )
  
  assign(cache_key, res$total, envir = normal_loudness_cache)
  return(res$total)
} 
