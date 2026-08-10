library(devtools)
load_all()

# We will redefine the function slightly to accept parameters
evaluate_params <- function(mu_slope, mu_max, slb_slope, slb_cap, mpo_buffer) {
  
  # Override the nalr.R calculate_open_nl_gain by assigning a new one into the namespace
  # Actually, since R allows lexical scoping, we can just copy the function and modify it.
  # But it's easier to just source a modified version. Let's instead write the logic directly.
  # Wait, sii() calls SII:::calculate_open_nl_gain. To override it, we can assign it to the namespace!
  
  original_fun <- SII:::calculate_open_nl_gain
  
  new_fun <- function(freq, threshold, input_level, gender = "male", experience = "experienced", config = "bilateral", age = "adult", coupling = "custom_occluded", module = "standard", ldl = NULL, age_years = NULL, age_months = NULL, loss = NULL, distortion_category = NULL, ten_edge_hf = NULL, ten_edge_lf = NULL, user_cr = NULL) {
    
    if (is.null(loss)) loss <- rep(0, length(threshold))
    sn_threshold <- pmax(0, threshold - loss)
    
    # MHL bypass omitted for brevity, assuming PTA > 25
    
    c_freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
    
    # 1. Base multiplier
    base_mult <- 0.35 + mu_slope * pmax(0, sn_threshold - 40)
    base_mult <- pmin(base_mult, mu_max)
    c_vals <- c(-8, -1, 3, 1, 0, 0, 0, 0)
    c_interp <- approx(x = log10(c_freqs), y = c_vals, xout = log10(freq), rule = 2)$y
    
    g_65 <- base_mult * sn_threshold + c_interp
    
    # 2. Severe-Loss Booster
    slb_raw <- pmax(0, sn_threshold - 60) * slb_slope
    slb_raw <- pmin(slb_raw, slb_cap)
    g_65 <- g_65 + slb_raw
    
    # 3. CR
    cr_loud <- 1 + (sn_threshold / 50)
    cr_loud <- pmin(cr_loud, 2.0)
    # Lower CR for severe losses
    cr_loud <- ifelse(sn_threshold > 70, 1.5, cr_loud)
    
    # 4. Multistage I/O (using critical band pivot)
    if (file.exists(file.path("data", "critical.rda"))) {
      load(file.path("data", "critical.rda"), envir = environment())
    } else {
      data("critical", package="SII", envir = environment())
    }
    pivot <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
    ct_band <- pivot + 5
    g_ct <- ifelse(ct_band > pivot, g_65, g_65 + (pivot - ct_band) * (1 - 1/cr_loud))
    
    ig <- ifelse(input_level <= ct_band, g_ct, g_ct - (input_level - ct_band) * (1 - 1/cr_loud))
    
    # MPO limit
    predicted_ldl_spl <- 100 + pmax(0, sn_threshold - 40) * 0.5 + loss
    mpo_spl_ceiling <- predicted_ldl_spl - mpo_buffer
    max_allowable_ig <- mpo_spl_ceiling - 85
    ig <- pmin(ig, max_allowable_ig, na.rm = TRUE)
    
    return(ig)
  }
  
  # Inject into namespace
  assignInNamespace("calculate_open_nl_gain", new_fun, ns="SII")
  
  freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
  a4_hl <- c(50, 50, 55, 65, 70, 75, 80, 80)
  a5_hl <- c(60, 65, 70, 75, 85, 90, 95, 95)
  
  s_a4 <- sii(speech="normal", threshold=a4_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)
  l_a4 <- calculate_loudness(s_a4)
  
  s_a5 <- sii(speech="normal", threshold=a5_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)
  l_a5 <- calculate_loudness(s_a5)
  
  return(list(sii_a4=s_a4$sii, loud_a4=l_a4, sii_a5=s_a5$sii, loud_a5=l_a5))
}

# Grid search
results <- list()
for (mu_max in c(0.50, 0.55, 0.60)) {
  for (slb_slope in c(0.5, 0.7, 1.0)) {
    for (mpo_buffer in c(12, 5, 0)) {
      res <- evaluate_params(mu_slope=0.005, mu_max=mu_max, slb_slope=slb_slope, slb_cap=30, mpo_buffer=mpo_buffer)
      
      score <- res$sii_a4 + res$sii_a5
      penalty <- 0
      if (res$loud_a4 > 12) penalty <- penalty + (res$loud_a4 - 12) * 10
      if (res$loud_a5 > 14) penalty <- penalty + (res$loud_a5 - 14) * 10
      
      results[[length(results)+1]] <- list(mu=mu_max, slb=slb_slope, mpo=mpo_buffer, 
                                           s_a4=res$sii_a4, l_a4=res$loud_a4,
                                           s_a5=res$sii_a5, l_a5=res$loud_a5,
                                           score=score - penalty)
    }
  }
}

# Find best
best <- results[[which.max(sapply(results, function(x) x$score))]]
cat(sprintf("BEST PARAMS: mu_max=%.2f, slb_slope=%.1f, mpo_buffer=%d\n", best$mu, best$slb, best$mpo))
cat(sprintf("A4 SII: %.2f (Loudness: %.1f)\n", best$s_a4, best$l_a4))
cat(sprintf("A5 SII: %.2f (Loudness: %.1f)\n", best$s_a5, best$l_a5))
