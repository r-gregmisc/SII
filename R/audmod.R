#' AMT 1.6.0 bramslow2004 (AUDMOD) Loudness Model
#'
#' This function computes the loudness of a signal using a faithful C++ port of the
#' AMT 1.6.0 bramslow2004 model (Bramslow Nielsen 1993; Bramslow 2004, 2024).
#'
#' @param freq Frequencies of the signal spectrum.
#' @param level_dB_per_Hz Signal spectrum levels in dB/Hz.
#' @param audiogram_freq Audiogram frequencies (Hz).
#' @param audiogram_HL Audiogram hearing loss (dB HL).
#' @param ucl_HL Uncomfortable loudness levels (dB HL). Defaults to 120 dB HL at all frequencies.
#' @param fs Sampling rate. Default is 32000.
#' @param N FFT size. Default is 8192.
#' @param Binaural 0 for monaural, 1 for binaural.
#' @param ref Optional reference object returned by a previous call.
#' @return A list containing total loudness (Ldn), specific loudness (N_prime), fc, E_Vector, and the reference object (ref).
#' @export
calculate_loudness_audmod <- function(freq, level_dB_per_Hz, audiogram_freq, audiogram_HL,
                                      ucl_HL = rep(120, 13), fs = 32000, N = 8192,
                                      Binaural = 0, ref = NULL) {
  
  amt_freqs <- c(125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500)
  
  hl_interp <- approx(x = log10(audiogram_freq), y = audiogram_HL, xout = log10(amt_freqs), rule = 2)$y
  
  if (is.null(ref)) {
    ref <- audmod_reference_cpp(fs = fs, N = N, AGLoss_HL = hl_interp, AG_UCL_HL = ucl_HL)
  }
  
  # Build PowSpect on the FFT grid
  j <- 1:(N/2)
  bin_freqs <- j * fs / N
  
  interp_spec <- approx(x = log10(freq), y = level_dB_per_Hz, xout = log10(bin_freqs), rule = 2)$y
  
  # Set power to 0 outside the given frequency range
  outside_range <- bin_freqs < min(freq) | bin_freqs > max(freq)
  PowSpect <- (10^(interp_spec / 10)) * (fs / N)
  PowSpect[outside_range] <- 0
  
  res <- audmod_loudness_cpp(PowSpect_in = PowSpect, fs = fs, N = N, ref = ref, Binaural = Binaural)
  
  list(
    total = res$Ldn,
    specific = res$N_prime,
    fc = res$fc,
    E = res$E_Vector,
    ref = ref
  )
}
