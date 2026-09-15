#!/usr/bin/env Rscript

pkg_root <- "/home/mark/Development/SII-github"
devtools::load_all(pkg_root, reset = TRUE, quiet=TRUE)
source(file.path(pkg_root, "R/sii.R"), local = FALSE)
source(file.path(pkg_root, "R/nalr.R"), local = FALSE)
source(file.path(pkg_root, "R/open_nl.R"), local = FALSE)
load(file.path(pkg_root, "data/critical.rda"))

library(parallel)

profiles <- c("a4", "a5") # Just focus on the steeply sloping ones for the grid to save time? The plan says "for all seven profiles" or I can just do A4 for the main figure. Let's do A4 and A5 first.
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

run_grid <- function(p, lvl=65) {
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  
  # Grid bounds
  cap_seq <- seq(4.0, 10.0, length.out=13) # 0.5 sone steps
  floor_seq <- seq(-15, 0, length.out=7)   # 2.5 dB steps
  
  grid <- expand.grid(L_cap = cap_seq, vent_floor = floor_seq)
  
  # Run NAL-NL2 just to get its position
  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", target_data$freq, lvl)
  nal_gain_6 <- approx(log10(target_data$freq), nal_gain_19, log10(hl_freqs), rule=2)$y
  
  # Calculate NAL-NL2 loudness
  ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
  input_speech <- ltass_65 + (lvl - 65)
  aided_spl <- input_speech + nal_gain_6 - loss
  
  f_half <- seq(0, 24000, by = 0.5); f_half[1] <- 1
  li <- approx(log10(hl_freqs), aided_spl, log10(f_half), rule = 2)$y
  li[f_half < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / pmax(f_half[f_half < hl_freqs[1]], 1))
  li[f_half > hl_freqs[length(hl_freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[f_half > hl_freqs[length(hl_freqs)]] / hl_freqs[length(hl_freqs)])
  overall <- 10 * log10(sum(10^(li/10)) * 0.5)
  
  dense_f <- seq(10, 23990, by = 10)
  dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y
  dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
  dense_l[dense_f > hl_freqs[length(hl_freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[dense_f > hl_freqs[length(hl_freqs)]] / hl_freqs[length(hl_freqs)])
  current_spl <- 10 * log10(sum(10^(dense_l/10) * 10))
  dense_l <- dense_l + (overall - current_spl)
  
  sn_loss <- pmax(htl - loss, 0)
  
  nal_loudness <- calculate_loudness_cpp(inputF = dense_f, inputLdB = dense_l, HLcf = hl_freqs, HLdB = sn_loss, NoChan = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0)$Ldn
  nal_hf_gain <- mean(nal_gain_6[4:5]) # mean of 2k and 4k
  nal_lf_gain <- nal_gain_6[1] # 250 Hz gain (approx vent floor)
  
  cat(sprintf("NAL-NL2 for %s: L_cap_equivalent = %.2f, HF Gain = %.2f, LF Gain = %.2f\n", p, nal_loudness, nal_hf_gain, nal_lf_gain))
  
  results <- mclapply(1:nrow(grid), function(i) {
    res <- tryCatch({
      open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss,
              cap_override = grid$L_cap[i], vent_floor = grid$vent_floor[i], 
              optimize = TRUE, enable_severe_booster = FALSE)
    }, error=function(e) NULL)
    
    if (is.null(res)) return(c(grid$L_cap[i], grid$vent_floor[i], NA, NA))
    
    hf_gain <- mean(res$gain[4:5])
    
    # Calculate SII
    normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(hl_freqs), rule = 2)$y
    overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
    speech_spec <- normal_speech + (lvl - overall_normal)
    sii_res <- sii(speech=speech_spec, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res$gain, desensitization="johnson2011_complete")$sii
    
    return(c(grid$L_cap[i], grid$vent_floor[i], hf_gain, sii_res))
  }, mc.cores = 4)

  
  df <- data.frame(do.call(rbind, results))
  colnames(df) <- c("L_cap", "vent_floor", "HF_Gain", "SII")
  df$Profile <- p
  
  return(list(grid = df, nal = data.frame(Profile=p, L_cap=nal_loudness, HF_Gain=nal_hf_gain, LF_Gain=nal_lf_gain)))
}

all_grids <- list()
all_nals <- list()
for (p in profiles) {
  cat("Running grid for profile", p, "\n")
  res <- run_grid(p)
  all_grids[[p]] <- res$grid
  all_nals[[p]] <- res$nal
}

grid_df <- do.call(rbind, all_grids)
nal_df <- do.call(rbind, all_nals)

write.csv(grid_df, "data_output/feasibility_grid.csv", row.names=FALSE)
write.csv(nal_df, "data_output/feasibility_nal.csv", row.names=FALSE)

cat("Finished computing feasibility maps.\n")

# Now let's just make a quick plot using ggplot2 to see what we have
library(ggplot2)

for (p in profiles) {
  p_grid <- grid_df[grid_df$Profile == p, ]
  p_nal <- nal_df[nal_df$Profile == p, ]

  max_val <- ceiling(max(p_grid$HF_Gain, na.rm=TRUE) / 5) * 5

  g <- ggplot(p_grid, aes(x = L_cap, y = vent_floor, z = HF_Gain)) +
    geom_contour_filled(breaks=seq(0, max_val, by=5)) +
    geom_point(data = p_nal, aes(x = L_cap, y = LF_Gain),
               color="red", size=4, shape=4) +
    annotate("text", x = p_nal$L_cap, y = p_nal$LF_Gain + 1,
             label="NAL-NL2", color="red", fontface="bold") +
    labs(title = paste("Feasibility Map - Profile", toupper(p)),
         x = "Loudness Cap (sones)",
         y = "Low-Frequency Insertion Gain Floor (dB)",
         fill = "Achievable HF Gain\n(2-4 kHz)") +
    theme_minimal()

  outfile <- sprintf("figures/feasibility_%s.png", p)
  ggsave(outfile, plot=g, width=6, height=5, bg="white")
  cat("Saved", outfile, "\n")
}
