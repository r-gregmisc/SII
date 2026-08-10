library(devtools)
load_all()

evaluate_params <- function(mu_base, mu_slope, mu_max, slb_thresh, slb_slope, slb_cap) {
  
  new_fun <- function(freq, threshold, input_level, gender = "male", experience = "experienced", config = "bilateral", age = "adult", coupling = "custom_occluded", module = "standard", ldl = NULL, age_years = NULL, age_months = NULL, loss = NULL, distortion_category = NULL, ten_edge_hf = NULL, ten_edge_lf = NULL, user_cr = NULL) {
    
    if (is.null(loss)) loss <- rep(0, length(threshold))
    sn_threshold <- pmax(0, threshold - loss)
    
    c_freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
    
    base_mult <- mu_base + mu_slope * pmax(0, sn_threshold - 40)
    base_mult <- pmin(base_mult, mu_max)
    c_vals <- c(-8, -1, 3, 1, 0, 0, 0, 0)
    c_interp <- approx(x = log10(c_freqs), y = c_vals, xout = log10(freq), rule = 2)$y
    
    g_65 <- base_mult * sn_threshold + c_interp
    
    slb_raw <- pmax(0, sn_threshold - slb_thresh) * slb_slope
    slb_raw <- pmin(slb_raw, slb_cap)
    g_65 <- g_65 + slb_raw
    
    cr_loud <- 1 + (sn_threshold / 50)
    cr_loud <- pmin(cr_loud, 2.0)
    
    if (file.exists(file.path("data", "critical.rda"))) {
      load(file.path("data", "critical.rda"), envir = environment())
    } else {
      data("critical", package="SII", envir = environment())
    }
    pivot <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
    ct_band <- pivot + 5
    g_ct <- ifelse(ct_band > pivot, g_65, g_65 + (pivot - ct_band) * (1 - 1/cr_loud))
    
    ig <- ifelse(input_level <= ct_band, g_ct, g_ct - (input_level - ct_band) * (1 - 1/cr_loud))
    
    predicted_ldl_spl <- 100 + pmax(0, sn_threshold - 40) * 0.5 + loss
    mpo_spl_ceiling <- predicted_ldl_spl - 5
    
    max_allowable_ig <- mpo_spl_ceiling - input_level
    ig <- pmin(ig, max_allowable_ig, na.rm = TRUE)
    
    return(ig)
  }
  
  assignInNamespace("calculate_open_nl_gain", new_fun, ns="SII")
  
  freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
  a4_hl <- c(50, 50, 55, 65, 70, 75, 80, 80)
  a5_hl <- c(60, 65, 70, 75, 85, 90, 95, 95)
  
  s_a4 <- sii(speech="normal", threshold=a4_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)
  l_a4 <- calculate_loudness(s_a4)
  
  s_a5 <- sii(speech="normal", threshold=a5_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)
  l_a5 <- calculate_loudness(s_a5)
  
  return(list(s_a4=s_a4$sii, l_a4=l_a4, s_a5=s_a5$sii, l_a5=l_a5))
}

results <- list()
for (mu_base in c(0.35, 0.40)) {
  for (mu_slope in c(0.003, 0.005)) {
    for (slb_thresh in c(50, 60)) {
      for (slb_slope in c(0.5, 0.75)) {
        res <- evaluate_params(mu_base, mu_slope, 0.60, slb_thresh, slb_slope, 30)
        
        # We want to maximize SII, but penalize if loudness > 15
        score <- res$s_a4 + res$s_a5
        penalty <- 0
        if (res$l_a4 > 15) penalty <- penalty + (res$l_a4 - 15) * 5
        if (res$l_a5 > 15) penalty <- penalty + (res$l_a5 - 15) * 5
        
        results[[length(results)+1]] <- list(mb=mu_base, ms=mu_slope, st=slb_thresh, ss=slb_slope,
                                             s_a4=res$s_a4, l_a4=res$l_a4,
                                             s_a5=res$s_a5, l_a5=res$l_a5,
                                             score=score - penalty)
      }
    }
  }
}

best <- results[[which.max(sapply(results, function(x) x$score))]]
cat(sprintf("BEST PARAMS: mu_base=%.2f, mu_slope=%.3f, slb_thresh=%d, slb_slope=%.2f\n", best$mb, best$ms, best$st, best$ss))
cat(sprintf("A4 SII: %.2f (Loudness: %.1f)\n", best$s_a4, best$l_a4))
cat(sprintf("A5 SII: %.2f (Loudness: %.1f)\n", best$s_a5, best$l_a5))
