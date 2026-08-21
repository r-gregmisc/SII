benchmark_reference_audiograms <- function() {
  source("R/benchmark_targets.R")
  source("R/sii.R")
  source("R/nalr.R")
  source("R/moore_glasberg.R")
  
  results <- data.frame()
  presets <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
  formulas <- c("NAL-NL2", "DSL", "CAMEQ2-HF", "Open-NL")
  
  for (preset in presets) {
    data <- jd2011_targets[[preset]]
    freq <- data$freq
    threshold <- data$threshold
    loss_vals <- if(is.null(data$loss)) rep(0, length(freq)) else data$loss
    
    for (formula in formulas) {
      if (formula == "Open-NL") {
        # Let the sii() engine correctly translate broadband 65 dB SPL "normal" speech into band levels
        res <- sii(speech = "normal", 
                   threshold = threshold, 
                   loss = loss_vals,
                   freq = freq, 
                   method = "octave", 
                   prescription = "Open-NL")
        gain <- res$gain
      } else {
        # Get target gain
        gain <- get_jd2011_target(preset, formula, target_freqs = freq, level = 65)
        
        # Calculate SII and Loudness using custom gain for NAL/DSL
        res <- sii(speech = "normal", 
                   threshold = threshold, 
                   loss = loss_vals,
                   freq = freq, 
                   method = "octave", 
                   custom_gain = gain)
      }
                 
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
