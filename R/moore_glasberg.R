#' Calculate Loudness for Cochlear Hearing Loss
#'
#' Fast excitation pattern estimation based on Chen et al. 2011 (JASA)
#' "A new model for calculating auditory excitation patterns and loudness 
#' for cases of cochlear hearing loss."
#' This implements the Moore & Glasberg (2004) excitation model.
#'
#' @param inputF Vector of dense input frequency values (Hz, typically 1 Hz spaced)
#' @param inputLdB Vector of input spectrum levels (dB/Hz)
#' @param HLcf Audiogram frequencies
#' @param HLohcdB0 OHC loss at audiogram frequencies
#' @param HLihcdB0 IHC loss at audiogram frequencies
#' @param cambin Spacing [ERB] between successive auditory filter CFs
#' @param flow Lowest center frequency of an auditory filter
#' @param fhigh Highest center frequency of an auditory filter
#' @param outerearcorrection 'FreeField', 'PDR10', or 'Eardrum'
#'
#' @return A list containing Loudness (sones), Excitation, Cams, and CFs.
#' @export
calculate_loudness_chen2011 <- function(inputF, inputLdB, HLcf=NULL, HLohcdB0=NULL, HLihcdB0=NULL, cambin=0.1, flow=50, fhigh=15000, outerearcorrection='FreeField') {
  
  if (length(inputF) != length(inputLdB)) {
    stop('inputF and inputLdB should be dB/Hz and have same length')
  }
  
  # calculation of auditory filter CF
  f2erbrate <- function(f) { 21.4 * log10(4.37 * f/1000 + 1) }
  erbrate2f <- function(c) { 1000 * (10^(c/21.4) - 1) / 4.37 }
  
  Cam <- seq(f2erbrate(flow), f2erbrate(fhigh), by=cambin)
  CF <- erbrate2f(Cam)
  
  if (is.null(HLcf) || is.null(HLohcdB0) || is.null(HLihcdB0)) {
    HLohcdB <- rep(0, length(CF))
    HLihcdB <- rep(0, length(CF))
  } else {
    HLohcdB <- approx(HLcf, HLohcdB0, xout=CF, rule=2)$y
    HLihcdB <- approx(HLcf, HLihcdB0, xout=CF, rule=2)$y
  }
  HLohcdB <- pmax(HLohcdB, 0)
  HLihcdB <- pmax(HLihcdB, 0)
  
  # step1: outer ear correction
  if (outerearcorrection == 'FreeField') {
    freefield_F <- c(0, 20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 750, 800, 1000, 1250, 1500, 1600, 2000, 2500, 3000, 3150, 4000, 5000, 6000, 6300, 8000, 9000, 10000, 11200, 12500, 14000, 15000, 16000, 20000)
    freefield_dB <- c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0.1, 0.3, 0.5, 0.9, 1.4, 1.6, 1.7, 2.5, 2.7, 2.6, 2.6, 3.2, 5.2, 6.6, 12, 16.8, 15.3, 15.2, 14.2, 10.7, 7.1, 6.4, 1.8, -0.9, -1.6, 1.9, 4.9, 2, -2, 2.5, 2.5)
    inputLdB <- inputLdB + approx(freefield_F, freefield_dB, xout=inputF, rule=2)$y
  } else if (outerearcorrection == 'Eardrum') {
    # No correction
  } else {
    stop('No such correction')
  }
  
  # step2: middle ear correction
  MidEar_F <- c(20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 750, 800, 1000, 1250, 1500, 1600, 2000, 2500, 3000, 3150, 4000, 5000, 6000, 6300, 8000, 9000, 10000, 11200, 12500, 14000, 15000, 16000, 20000)
  MidEar_dB <- c(-33.2, -28.2, -23.2, -19.4, -16.3, -13.3, -10.2, -8.0, -6.1, -4.7, -3.5, -2.8, -2.4, -1.9, -1.8, -2.1, -2.5, -2.3, -2.6, -3.7, -5.5, -6.7, -11.4, -14.5, -11.5, -11.0, -10.5, -10.8, -12.8, -13.6, -16.5, -15.8, -15.0, -16.9, -18.8, -20.7, -21.9, -22.3, -24.1)
  
  inputLdB <- inputLdB + approx(MidEar_F, MidEar_dB, xout=inputF, rule=2)$y
  inputL <- 10^(inputLdB/10)
  
  # step3: passive filter
  tl <- CF / (0.1084*CF + 2.3301)
  tu <- rep(15.0, length(CF))
  
  # Matrix-based Vectorization for massive speedup
  # Compute normalized frequency deviations (g) for all inputF and CF combinations
  g_mat <- outer(inputF, CF, function(x, y) x / y - 1)
  
  # Negative and positive parts of g
  g_neg <- pmax(0, -g_mat) # equivalent to abs(g) where g < 0
  g_pos <- pmax(0, g_mat)  # equivalent to abs(g) where g >= 0
  
  # Expand tl and tu to match matrix dimensions
  tl_mat <- matrix(tl, nrow=length(inputF), ncol=length(CF), byrow=TRUE)
  tu_mat <- matrix(tu, nrow=length(inputF), ncol=length(CF), byrow=TRUE)
  
  # Calculate filter weights for negative and positive deviations
  term_neg <- (1 + g_neg * tl_mat) * exp(-g_neg * tl_mat)
  term_pos <- (1 + g_pos * tu_mat) * exp(-g_pos * tu_mat)
  
  # Combine weights using a mask (where g < 0)
  mask_neg <- g_mat < 0
  weight_mat_pf <- matrix(0, nrow=length(inputF), ncol=length(CF))
  weight_mat_pf[mask_neg] <- term_neg[mask_neg]
  weight_mat_pf[!mask_neg] <- term_pos[!mask_neg]
  
  # Multiply by inputL and sum over frequencies
  E_pf <- colSums(weight_mat_pf * inputL)
  
  E_pf <- pmax(E_pf, 10^(-10))
  EdB_pf <- 10*log10(E_pf)
  EdB_pf <- pmax(EdB_pf, 0)
  
  # step4: gain decided by passive input
  GdBmax <- CF / (0.0191*CF + 1.1) - HLohcdB
  
  GdB <- GdBmax * ( 1 - 1/(1+exp(-0.05*(EdB_pf-(100-GdBmax)))) + 1/(1+exp(-0.05*(0-(100-GdBmax)))) )
  index <- which(EdB_pf > 30)
  if (length(index) > 0) {
    GdB[index] <- GdB[index] - 0.003 * (EdB_pf[index]-30)^2
  }
  
  GdB <- pmin(pmax(GdB, -20), GdBmax)
  G <- 10^(GdB/10)
  
  # step5: active tip filter (af)
  pl <- CF / (0.0272*CF + 5.4365)
  pu <- rep(27.9, length(CF))
  
  pl_mat <- matrix(pl, nrow=length(inputF), ncol=length(CF), byrow=TRUE)
  pu_mat <- matrix(pu, nrow=length(inputF), ncol=length(CF), byrow=TRUE)
  
  term_neg_af <- (1 + g_neg * pl_mat) * exp(-g_neg * pl_mat)
  term_pos_af <- (1 + g_pos * pu_mat) * exp(-g_pos * pu_mat)
  
  weight_mat_af <- matrix(0, nrow=length(inputF), ncol=length(CF))
  weight_mat_af[mask_neg] <- term_neg_af[mask_neg]
  weight_mat_af[!mask_neg] <- term_pos_af[!mask_neg]
  
  # Compute active excitation by summing and multiplying by active gain G
  E_af <- G * colSums(weight_mat_af * inputL)
  
  E <- E_pf + E_af
  E <- pmax(E, 10^(-10))
  EdB <- 10*log10(E)
  
  EdB <- EdB - HLihcdB * (1 - 0.5/(1+exp(-0.2*((EdB-52)-(HLihcdB+20)))))
  E <- 10^(EdB/10)
  
  # ---- Specific Loudness Computation (Moore, Glasberg & Baer, 1997) ----
  # Convert cochlear excitation to specific loudness.
  # Normal hearing uses a highly compressive exponent (alpha = 0.2).
  # Impaired hearing (OHC loss) loses compression, so alpha approaches 1.0 (linear).
  # Critically, as alpha increases, the scaling constant C MUST decrease so that 
  # loudness recruitment is complete (impaired = normal) at 100 dB SPL (E = 1e10).
  
  # Normal parameters
  G_norm <- 10^( (CF / (0.0191*CF + 1.1)) / 10 ) # Normal active gain
  A_norm <- G_norm * 1.5 # Internal noise excitation
  
  # Impaired parameters
  A <- A_norm
  
  # Calculate alpha: 0.2 for normal, approaches 1.0 for OHC loss
  g_norm_dB <- CF / (0.0191*CF + 1.1)
  g_imp_dB <- pmax(g_norm_dB - HLohcdB, 0.1)
  alpha <- pmin(1.0, 0.2 * (g_norm_dB / g_imp_dB))
  
  # Calculate the actual impaired excitation at 100 dB SPL (E_100_imp)
  # A 100 dB SPL signal is attenuated by the IHC loss function
  EdB_100 <- rep(100, length(CF))
  EdB_100_imp <- EdB_100 - HLihcdB * (1 - 0.5/(1+exp(-0.2*((EdB_100-52)-(HLihcdB+20)))))
  E_100_imp <- 10^(EdB_100_imp/10)
  
  # Normal loudness at 100 dB SPL
  E_100_norm <- 1e10
  N_norm_100 <- 0.046871 * ( (E_100_norm + A_norm)^0.2 - A_norm^0.2 )
  
  # C_imp anchors the impaired specific loudness to equal normal loudness at 100 dB SPL
  C_imp <- N_norm_100 / ( (E_100_imp + A)^alpha - A^alpha )
  
  # Specific loudness (sones/ERB)
  # Below 100 dB SPL, use the impaired recruitment function
  N_prime_imp <- C_imp * ( (E + A)^alpha - A^alpha )
  
  # Above 100 dB SPL, recruitment is complete, so loudness reverts to the normal ear's compressive function
  # We must use the theoretical UNATTENUATED normal energy for SPLs > 100 dB to match normal loudness correctly.
  E_unattenuated <- 10^( (EdB + HLihcdB * (1 - 0.5/(1+exp(-0.2*((EdB-52)-(HLihcdB+20)))))) / 10 )
  N_prime_norm <- 0.046871 * ( (E_unattenuated + A_norm)^0.2 - A_norm^0.2 )
  
  # Crossover at the impaired 100 dB SPL threshold
  N_prime <- ifelse(E > E_100_imp, N_prime_norm, N_prime_imp)
  # Prevent any mathematical underflows yielding negative loudness
  N_prime <- pmax(0, N_prime)
  
  # Total loudness is the integral across the ERB scale
  Ldn <- sum(N_prime) * cambin

  return(list(Ldn=Ldn, N_prime=N_prime, E=E, Cam=Cam, CF=CF))
}

#' Convert 1/3-octave band levels to 1 Hz spectrum density
#'
#' @param fc Center frequencies of 1/3 octave bands
#' @param level dB SPL in each band
#' @return A list containing `f` (1 Hz frequencies) and `l_density` (spectrum levels)
#' @export
convert_1_3_octave_to_density <- function(fc, level) {
  dense_f <- seq(20, 20000, by=1)
  dense_l <- rep(-100, length(dense_f)) # noise floor
  
  fd <- 2^(1/6)
  lower_bounds <- fc / fd
  upper_bounds <- fc * fd
  bandwidths <- upper_bounds - lower_bounds
  
  density_levels <- level - 10*log10(bandwidths)
  
  for (i in 1:length(fc)) {
    idx <- which(dense_f >= lower_bounds[i] & dense_f <= upper_bounds[i])
    dense_l[idx] <- density_levels[i]
  }
  
  # Roll off low frequencies below the first band rather than extrapolating flat
  # Flat extrapolation applies too much energy if the first band contains insertion gain
  idx_low <- which(dense_f < lower_bounds[1])
  if (length(idx_low) > 0) {
    # 24 dB/octave roll-off
    octaves_below <- log2(lower_bounds[1] / dense_f[idx_low])
    dense_l[idx_low] <- density_levels[1] - 24 * octaves_below
  }
  
  # Flat extrapolation above the last band
  idx_high <- which(dense_f > upper_bounds[length(upper_bounds)])
  if (length(idx_high) > 0) {
    dense_l[idx_high] <- density_levels[length(density_levels)]
  }
  
  return(list(f = dense_f, l_density = dense_l))
}
