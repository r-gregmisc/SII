#' Predict Aided Speech Intelligibility Index (SII)
#'
#' @description
#' Uses multiple linear regression equations from Johnson (2013) to accurately predict 
#' the aided Speech Intelligibility Index (SII) for a 65 dB SPL average speech input. 
#' The predictions approximate the full 2,160-step ANSI S3.5 calculation based on pure 
#' tone averages (PTA).
#'
#' @param freq A numeric vector of frequencies (in Hz) corresponding to the \code{threshold} values.
#' @param threshold A numeric vector of hearing thresholds (in dB HL).
#' @param age A character string specifying the patient age group. Must be either \code{"adult"} (default) or \code{"pediatric"} (modeled on 3-year-olds).
#' @param prescription A character string specifying the proprietary prescriptive rationale to predict. Must be either \code{"NAL-NL2"} (default) or \code{"DSL"} (DSL m[i/o] v5.0).
#' @param desensitized Logical flag. If \code{TRUE}, predicts the effective SII incorporating hearing loss desensitization. If \code{FALSE} (default), predicts the traditional ANSI SII.
#'
#' @return A numeric value representing the predicted SII (constrained between 0.0 and 1.0).
#'
#' @references
#' Johnson, E. E. (2013). Modern prescription theory and application: realistic expectations for speech recognition with hearing aids. Trends in Amplification, 17(3/4), 143-170.
#'
#' @export
predict_aided_sii <- function(freq, threshold, age = c("adult", "pediatric"), prescription = c("NAL-NL2", "DSL"), desensitized = FALSE) {
  age <- match.arg(age)
  prescription <- match.arg(prescription)
  
  # Calculate PTAs
  # Interpolate if exact frequencies are not present
  pta1_freqs <- c(500, 1000, 2000)
  pta2_freqs <- c(3000, 4000, 6000)
  
  get_pta <- function(target_freqs) {
    if (all(target_freqs %in% freq)) {
      thresh <- threshold[match(target_freqs, freq)]
    } else {
      thresh <- approx(x = log10(freq), y = threshold, xout = log10(target_freqs), rule = 2)$y
    }
    return(mean(thresh, na.rm = TRUE))
  }
  
  pta1 <- get_pta(pta1_freqs)
  pta2 <- get_pta(pta2_freqs)
  
  sii <- NA
  
  if (age == "adult") {
    if (prescription == "NAL-NL2") {
      if (desensitized) {
        sii <- -0.008 * pta1 - 0.005 * pta2 + 1.294
      } else {
        sii <- -0.007 * pta1 - 0.004 * pta2 + 1.299
      }
    } else if (prescription == "DSL") {
      if (desensitized) {
        sii <- -0.008 * pta1 - 0.005 * pta2 + 1.310
      } else {
        sii <- -0.005 * pta1 - 0.003 * pta2 + 1.237
      }
    }
  } else if (age == "pediatric") {
    if (prescription == "NAL-NL2") {
      if (desensitized) {
        sii <- -0.0046 * pta1 - 0.0025 * pta2 + 0.711
      } else {
        sii <- -0.003 * pta1 - 0.002 * pta2 + 0.693
      }
    } else if (prescription == "DSL") {
      if (desensitized) {
        sii <- -0.0045 * pta1 - 0.0024 * pta2 + 0.688
      } else {
        sii <- -0.002 * pta1 - 0.001 * pta2 + 0.600
      }
    }
  }
  
  # Constrain between 0 and 1
  sii <- max(0, min(1, sii))
  
  return(sii)
}
