library(SII)
library(ggplot2)

# A5 profile
f_htl <- c(250, 500, 1000, 2000, 4000, 8000)
threshold <- c(10, 10, 20, 60, 80, 100)
loss <- rep(0, 6)
hl_freqs <- f_htl
ihc_loss <- rep(0, 6)
ohc_loss <- threshold # Assuming pure OHC loss for simplicity here

# Generate the base target
base_target <- SII:::calculate_open_nl_gain(
  f_htl, threshold, 65, "male", "experienced", "bilateral", 
  "custom_occluded", "standard", NULL, loss, NULL, NULL, 0.75, FALSE, FALSE
)

# Extract internal parameters from critical band
data("critical", package="SII")
fi <- critical$fi
speech <- critical$normal + (65 - 62.35)
htl_21 <- approx(x = log10(f_htl), y = threshold, xout = log10(fi), rule = 2)$y

calc_obj <- function(shift2k, shift4k) {
  shifts <- c(0, 0, 0, shift2k, shift4k, 0)
  temp_target <- base_target + shifts
  
  out_of_bounds_penalty <- 0.0
  if (any(temp_target < -10)) {
    out_of_bounds_penalty <- sum(abs(temp_target[temp_target < -10] + 10)) * 100
  }
  if (any(temp_target > 80)) {
    out_of_bounds_penalty <- out_of_bounds_penalty + sum(abs(temp_target[temp_target > 80] - 80)) * 100
  }
  
  res <- tryCatch({
    sii(speech = speech, threshold = htl_21, freq = fi, loss = rep(0, length(fi)),
        prescription = temp_target, interpolate = TRUE, 
        nal_ldf = TRUE, desensitization = "johnson2011_smoothed")
  }, error = function(e) NULL)
  
  if (is.null(res)) return(NA)
  
  score <- res$sii * 100.0
  
  # Calculate SPL
  Ei <- res$table[, "E'i"]
  fi_res <- res$table[, "Fi"]
  overall_spl <- 10 * log10(sum(10^(Ei / 10) * 10, na.rm=TRUE))
  spl_penalty <- 0.0
  if (is.finite(overall_spl) && overall_spl > 110.0) {
    spl_penalty <- (overall_spl - 110.0) * 500.0
  }
  
  # Calculate Loudness
  loud_res <- tryCatch({
    SII:::calculate_loudness(res)
  }, error = function(e) NULL)
  
  loudness_penalty <- 0.0
  if (!is.null(loud_res)) {
    loudness_sones <- loud_res$total
    pta_sn_local <- mean(threshold[c(2, 3, 4, 5)], na.rm = TRUE)
    dynamic_cap <- max(6.5, 2.5 + 0.12 * pta_sn_local)
    
    if (loudness_sones > dynamic_cap) {
      excess <- loudness_sones - dynamic_cap
      loudness_penalty <- excess * 500.0 
    }
  } else {
    return(NA)
  }
  
  anchor_penalty <- sum(abs(shifts)) * 0.1
  
  # Return penalized loss (lower is better in optim, so we return the objective function value)
  return(-score + anchor_penalty + loudness_penalty + out_of_bounds_penalty + spl_penalty)
}

# Grid over 2kHz and 4kHz shifts (50x50)
grid_2k <- seq(-15, 15, length.out = 50)
grid_4k <- seq(-15, 15, length.out = 50)

df <- expand.grid(shift2k = grid_2k, shift4k = grid_4k)
df$Loss <- apply(df, 1, function(x) calc_obj(x[1], x[2]))

# Filter out NAs
df <- df[!is.na(df$Loss), ]

# To make the plot readable (avoiding massive penalty spikes skewing the color scale),
# we cap the Loss at the 95th percentile
cap_val <- quantile(df$Loss, 0.95, na.rm = TRUE)
df$Loss[df$Loss > cap_val] <- cap_val

p <- ggplot(df, aes(x = shift2k, y = shift4k, z = Loss)) +
  geom_contour_filled(bins = 15) +
  scale_fill_viridis_d(direction = -1) +
  theme_minimal() +
  labs(title = "Open-NL Objective Function Landscape (A5 Profile)",
       subtitle = "Optimization landscape varying 2 kHz and 4 kHz gain shifts",
       x = "2 kHz Gain Shift (dB)",
       y = "4 kHz Gain Shift (dB)",
       fill = "Objective Loss") +
  theme(legend.position = "right")

ggsave("Figure5_Objective_Landscape.png", plot = p, width = 7, height = 5)
