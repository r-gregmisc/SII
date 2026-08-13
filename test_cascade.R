library(SII)

freq <- c(250, 500, 1000, 2000, 4000, 8000)
# A5 profound steeply sloping loss
threshold <- c(15, 20, 50, 75, 90, 95)
sn_threshold <- threshold

# 1. Base Anchor
c_vals <- c(-8, -1, 3, 1, 0, 0, 0, 0)
c_interp <- approx(x = log10(c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)), y = c_vals, xout = log10(freq), rule = 2)$y

# === CORRECT ORDER ===
g_correct <- 0.46 * sn_threshold + c_interp
# Step A: Severe Loss Booster
g_correct <- g_correct + 0.15 * pmax(0, sn_threshold - 60)
# Step B: SD-LFP (A5 has steep slope)
pta_lf <- mean(sn_threshold[freq <= 1000]); pta_hf <- mean(sn_threshold[freq >= 2000])
slope_diff <- pta_hf - pta_lf
lf_penalty_max <- pmin(1, (slope_diff - 15) / 20) * 15
lf_weights <- pmax(0, 1 - (log10(freq) - log10(250)) / log10(1000/250))
g_correct <- g_correct - (lf_penalty_max * lf_weights)
# Step C: High-Frequency Desensitization
gain_limit <- 45 + pmax(0, sn_threshold - 60) * 1.0
excess_gain <- pmax(0, g_correct - gain_limit)
best_low_thresh <- min(sn_threshold[freq <= 1000])
slope_factor <- pmax(0, pmin(1, (sn_threshold - best_low_thresh - 25) / 20))
hf_weight <- pmax(0, pmin(1, (freq - 2000) / 2000))
g_correct <- g_correct - (excess_gain * slope_factor * hf_weight) + ((excess_gain * slope_factor * hf_weight) / 3.0)


# === SCRAMBLED ORDER ===
g_scrambled <- 0.46 * sn_threshold + c_interp
# Step C: High-Frequency Desensitization (BEFORE BOOSTER)
excess_gain_s <- pmax(0, g_scrambled - gain_limit)
g_scrambled <- g_scrambled - (excess_gain_s * slope_factor * hf_weight) + ((excess_gain_s * slope_factor * hf_weight) / 3.0)
# Step A: Severe Loss Booster (AFTER LIMITER)
g_scrambled <- g_scrambled + 0.15 * pmax(0, sn_threshold - 60)
# Step B: SD-LFP
g_scrambled <- g_scrambled - (lf_penalty_max * lf_weights)


cat("Correct Cascade Seed Gain:   ", round(g_correct, 1), "\n")
cat("Scrambled Cascade Seed Gain: ", round(g_scrambled, 1), "\n")

# Reconstruct dummy prescription objects
inputF <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
speech_spec <- c(63, 60, 53, 47, 44, 42, 40, 39)
speech_spec_65 <- approx(x = log10(inputF), y = speech_spec, xout = log10(freq), rule = 2)$y

mpo_correct <- calculate_nal_sspl90(threshold, g_correct, NULL, "adult", NULL, rep(0, 6), freq)
mpo_scrambled <- calculate_nal_sspl90(threshold, g_scrambled, NULL, "adult", NULL, rep(0, 6), freq)

t_correct <- list(freq=freq, gain=g_correct, mpo=mpo_correct, speech=speech_spec_65, threshold=threshold, loss=rep(0,6), module="standard", overall_level=65)
class(t_correct) <- "prescription_target"
s_correct <- sii(speech=speech_spec_65, noise=rep(-50,6), threshold=threshold, loss=rep(0,6), freq=freq, prescription=t_correct, interpolate=TRUE, nal_ldf=TRUE, desensitization=TRUE)

t_scrambled <- list(freq=freq, gain=g_scrambled, mpo=mpo_scrambled, speech=speech_spec_65, threshold=threshold, loss=rep(0,6), module="standard", overall_level=65)
class(t_scrambled) <- "prescription_target"
s_scrambled <- sii(speech=speech_spec_65, noise=rep(-50,6), threshold=threshold, loss=rep(0,6), freq=freq, prescription=t_scrambled, interpolate=TRUE, nal_ldf=TRUE, desensitization=TRUE)


get_loudness <- function(res) {
    fi <- res$table[, "Fi"]
    Ei <- res$table[, "E'i"]
    dense_f <- 10^(seq(log10(100), log10(10000), length.out = 100))
    dense_l <- approx(x = log10(fi), y = Ei, xout = log10(dense_f), rule = 1)$y
    idx_low <- which(dense_f < fi[1])
    if (length(idx_low) > 0) dense_l[idx_low] <- Ei[1] - 24 * log2(fi[1] / dense_f[idx_low])
    idx_high <- which(dense_f > fi[length(fi)])
    if (length(idx_high) > 0) dense_l[idx_high] <- Ei[length(Ei)] - 24 * log2(dense_f[idx_high] / fi[length(fi)])
    dense_l[is.na(dense_l)] <- -100
    
    hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
    htl <- approx(x = log10(freq), y = threshold, xout = log10(hl_freqs), rule = 2)$y
    sn_htl <- pmax(htl, 0)
    ohc_loss <- pmin(0.65 * sn_htl, 57.6)
    ihc_loss <- pmax(sn_htl - ohc_loss, 0)
    
    loud_res <- calculate_loudness_chen2011(inputF = dense_f, inputLdB = dense_l,
        HLcf = hl_freqs, HLohcdB0 = ohc_loss, HLihcdB0 = ihc_loss,
        cambin = 0.1, outerearcorrection = 'FreeField')
    return(loud_res$Ldn)
}

cat(sprintf("Correct Cascade   -> SII: %.4f | Loudness: %.2f sones\n", s_correct$sii, get_loudness(s_correct)))
cat(sprintf("Scrambled Cascade -> SII: %.4f | Loudness: %.2f sones\n", s_scrambled$sii, get_loudness(s_scrambled)))

