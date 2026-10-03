library(SII)
library(ggplot2)
library(reshape2)
source("R/benchmark_targets.R")
source("R/open_nl.R")
source("R/nalr.R")
Rcpp::sourceCpp("src/bramslow2004.cpp")

calc_amt_loudness <- function(gain_tgt, htl, cond, target_level) {
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  input_speech <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) + (target_level - 65)
  aided_spl <- input_speech + gain_tgt - cond
  f_half <- seq(0, 24000, by = 0.5)
  f_half[1] <- 1
  levels_interp <- approx(x = log10(freqs), y = aided_spl, xout = log10(f_half), rule = 2)$y
  idx_low <- which(f_half < freqs[1])
  if (length(idx_low) > 0) levels_interp[idx_low] <- aided_spl[1] - 24 * log2(freqs[1] / pmax(f_half[idx_low], 1))
  idx_high <- which(f_half > freqs[length(freqs)])
  if (length(idx_high) > 0) levels_interp[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[idx_high] / freqs[length(freqs)])
  overall <- 10 * log10(sum(10^(levels_interp/10)) * 0.5)
  dense_f <- seq(1, 24000, by = 5)
  dense_l <- approx(x = log10(freqs), y = aided_spl, xout = log10(dense_f), rule = 2)$y
  idx_low <- which(dense_f < freqs[1])
  if (length(idx_low) > 0) dense_l[idx_low] <- aided_spl[1] - 24 * log2(freqs[1] / dense_f[idx_low])
  idx_high <- which(dense_f > freqs[length(freqs)])
  if (length(idx_high) > 0) dense_l[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[idx_high] / freqs[length(freqs)])
  current_spl <- 10 * log10(sum(10^(dense_l/10) * 5))
  offset <- overall - current_spl
  dense_l <- dense_l + offset
  sn_loss <- htl - cond
  ohc <- sn_loss
  ihc <- rep(0, length(sn_loss))
  loudness_res <- calculate_loudness_cpp(
    inputF = dense_f, inputLdB = dense_l, HLcf = freqs, HLohcdB0 = ohc, HLihcdB0 = ihc, Binaural = 0
  )
  return(loudness_res$Ldn)
}

cat("Regenerating Manuscript Figures 1-3...\n")

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

df_sii <- data.frame(Profile = character(), Method = character(), SII = numeric(), stringsAsFactors=FALSE)
df_loud <- data.frame(Profile = character(), Method = character(), Sones = numeric(), stringsAsFactors=FALSE)
df_gain <- data.frame(Profile = character(), Method = character(), Freq = numeric(), Gain = numeric(), stringsAsFactors=FALSE)

for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- target_data$freq
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  nal_tgt <- calculate_nalr_gain(freq = freqs, threshold = threshold)
  opennl_tgt <- open_nl(speech=65, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60)
  
  obj_nal <- sii(speech=c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78), threshold=threshold, loss=loss, freq=freqs, prescription=nal_tgt, method="octave", transducer="none")
  obj_onl <- sii(speech=c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78), threshold=threshold, loss=loss, freq=freqs, prescription=opennl_tgt, method="octave", transducer="none")
  
  df_sii <- rbind(df_sii, data.frame(Profile=p_name, Method="NAL-R", SII=obj_nal$sii))
  df_sii <- rbind(df_sii, data.frame(Profile=p_name, Method="Open-NL", SII=obj_onl$sii))
  
  df_loud <- rbind(df_loud, data.frame(Profile=p_name, Method="NAL-R", Sones=calc_amt_loudness(nal_tgt, threshold, loss, 65)))
  df_loud <- rbind(df_loud, data.frame(Profile=p_name, Method="Open-NL", Sones=calc_amt_loudness(opennl_tgt$gain, threshold, loss, 65)))
  
  for (f_idx in seq_along(freqs)) {
    df_gain <- rbind(df_gain, data.frame(Profile=p_name, Method="NAL-R", Freq=freqs[f_idx], Gain=nal_tgt[f_idx]))
    df_gain <- rbind(df_gain, data.frame(Profile=p_name, Method="Open-NL", Freq=freqs[f_idx], Gain=opennl_tgt$gain[f_idx]))
  }
}

p1 <- ggplot(df_sii, aes(x=Profile, y=SII, fill=Method)) +
  geom_bar(stat="identity", position="dodge") +
  theme_minimal() +
  labs(title="Figure 1: Optimization of SII", y="Speech Intelligibility Index (SII)", x="Audiometric Profile")
ggsave("Figure1_Optimization_SII.png", plot=p1, width=7, height=5)

p2 <- ggplot(df_loud, aes(x=Profile, y=Sones, fill=Method)) +
  geom_bar(stat="identity", position="dodge") +
  theme_minimal() +
  labs(title="Figure 2: Modeled Monaural Loudness", y="Loudness (Sones)", x="Audiometric Profile")
ggsave("Figure2_Optimization_Loudness.png", plot=p2, width=7, height=5)

df_gain$Freq <- as.factor(df_gain$Freq)
p3 <- ggplot(df_gain, aes(x=Freq, y=Gain, color=Method, group=Method)) +
  geom_line() + geom_point() +
  facet_wrap(~Profile, scales="free_y") +
  theme_minimal() +
  labs(title="Figure 3: Insertion Gain Targets", y="Insertion Gain (dB)", x="Frequency (Hz)")
ggsave("Figure3_Insertion_Gain.png", plot=p3, width=10, height=7)

cat("Successfully regenerated Figures 1-3.\n")
