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
        # Actually run the Open-NL optimizer to get the prescribed target
        opt_res <- open_nl(speech = 65, threshold = threshold, freq = freq, loss = loss_vals)
        gain <- opt_res$gain
        
        # Then calculate the final SII and Loudness using the optimized gain
        res <- sii(speech = "normal", 
                   threshold = threshold, 
                   loss = loss_vals,
                   freq = freq, 
                   method = "octave", 
                   custom_gain = gain)
      } else {
        # Get target gain
        gain <- get_nalnl2_v2_target(preset, formula, target_freqs = freq, level = 65)
        
        # Calculate SII and Loudness using custom gain for NAL/DSL
        res <- sii(speech = "normal", 
                   threshold = threshold, 
                   loss = loss_vals,
                   freq = freq, 
                   method = "octave", 
                   custom_gain = gain)
      }
                 
      sone_res <- calculate_loudness(res)
      sone_val <- if (is.list(sone_res)) sone_res$total else sone_res
                 
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
