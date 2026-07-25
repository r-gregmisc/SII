benchmark_reference_audiograms <- function() {
  source("R/benchmark_targets.R")
  source("R/sii.R")
  source("R/nalr.R")
  
  results <- data.frame()
  presets <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
  formulas <- c("NAL-NL2", "DSL", "CAMEQ2-HF", "Open-NL")
  
  for (preset in presets) {
    data <- jd2011_targets[[preset]]
    freq <- data$freq
    threshold <- data$threshold
    
    for (formula in formulas) {
      if (formula == "Open-NL") {
        # Calculate Open-NL gain
        gain <- calculate_open_nl_gain(freq, threshold, input_level = 65, module = "standard")
      } else {
        # Get target gain
        gain <- get_jd2011_target(preset, formula, target_freqs = freq, level = 65)
      }
      
      # Calculate SII and Loudness using our internal functions
      # The reference audiograms use speech at 65 dB SPL and typical noise
      # Note: We pass custom_gain to bypass the internal prescription engine
      res <- sii(speech = "normal", 
                 threshold = threshold, 
                 freq = freq, 
                 method = "octave", 
                 custom_gain = gain)
                 
      sone_val <- calculate_loudness(res)
                 
      results <- rbind(results, data.frame(
        Audiogram = toupper(preset),
        Formula = formula,
        SII = round(res$sii, 2),
        Sones = round(sone_val, 1)
      ))
    }
  }
  
  return(results)
}
