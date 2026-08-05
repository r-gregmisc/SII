#' Open-NL WDRC Gain Prescription
#'
#' @param speech Input speech spectrum level at each frequency. If a single number is provided, it's assumed to be the overall broadband SPL.
#' @param threshold Hearing threshold level at each frequency.
#' @param freq Frequencies at which the thresholds are measured.
#' @param gender Gender of the patient ("male", "female").
#' @param experience Hearing aid experience ("new", "experienced", "power").
#' @param config Fitting configuration ("unilateral", "bilateral").
#' @param age Age group ("adult", "child_0_5", "child_6_11", "child_12_23", "child_24_35", "child_36_59", "child_60_plus").
#' @param coupling Acoustic coupling ("custom_occluded", "open_dome", "tulip_dome", "double_dome", "vent_1mm_solid", etc.).
#' @param module Fitting module ("standard", "cin", "mhl").
#' @param ldl Loudness Discomfort Levels (optional).
#' @param age_years Age in years (optional).
#' @param age_months Age in months (optional).
#' @param loss Conductive hearing loss component (optional).
#' @param distortion_category Distortion category ("Normal", "Low", "Moderate", "High").
#' @param ten_edge_hf High-frequency dead region edge (optional).
#' @param ten_edge_lf Low-frequency dead region edge (optional).
#'
#' @return An object of class \code{prescription_target}.
#' @export
open_nl <- function(speech = 65, threshold, freq, 
                    gender = "male", experience = "experienced", 
                    config = "bilateral", age = "adult", 
                    coupling = "custom_occluded", module = "standard", 
                    ldl = NULL, age_years = NULL, age_months = NULL, 
                    loss = NULL, distortion_category = NULL, 
                    ten_edge_hf = NULL, ten_edge_lf = NULL) {
  
  if (length(speech) == 1) {
    if (file.exists(file.path("data", "critical.rda"))) {
      load(file.path("data", "critical.rda"), envir = environment())
    } else {
      data("critical", package="SII", envir = environment())
    }
    # Interpolate critical band speech to requested frequencies
    normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
    overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
    speech_spec <- normal_speech + (speech - overall_normal)
    overall_level <- speech
  } else {
    speech_spec <- speech
    overall_level <- 65 # Fallback
  }
  
  gain <- calculate_open_nl_gain(freq, threshold, overall_level, gender, experience, config, age, coupling, module, ldl, age_years, age_months, loss, distortion_category, ten_edge_hf, ten_edge_lf)
  mpo <- calculate_nal_sspl90(threshold, gain, ldl, age, age_months, loss, freq)
  
  raw_output <- speech_spec + gain
  overshoot <- pmax(0, raw_output - mpo)
  final_output <- pmin(raw_output, mpo) + (overshoot / 10.0)
  
  final_gain <- pmax(final_output - speech_spec, 0)
  
  res <- list(
    freq = freq,
    gain = final_gain,
    mpo = mpo,
    speech = speech_spec,
    threshold = threshold,
    loss = loss,
    module = module,
    overall_level = overall_level
  )
  class(res) <- "prescription_target"
  return(res)
}

#' @export
print.prescription_target <- function(x, ...) {
  cat("Open-NL Prescription Target\n")
  cat(sprintf("Module: %s\n", x$module))
  cat(sprintf("Input Level: %.1f dB SPL\n", x$overall_level))
  cat("\nGain Targets:\n")
  df <- data.frame(Freq = x$freq, Gain = round(x$gain, 1), MPO = round(x$mpo, 1))
  print(df, row.names = FALSE)
}

#' @export
summary.prescription_target <- function(object, ...) {
  print(object)
}

#' @export
plot.prescription_target <- function(x, ...) {
  plot(x$freq, x$gain, type="l", log="x", 
       xlab="Frequency (Hz)", ylab="Insertion Gain (dB)",
       main=paste("Open-NL Target (", x$overall_level, " dB SPL)", sep=""),
       ylim=c(0, max(x$gain) + 10))
  points(x$freq, x$gain, pch=16)
  graphics::grid()
}
