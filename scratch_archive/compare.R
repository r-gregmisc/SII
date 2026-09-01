source("data_output/generate_open_nl_metrics.R")

cat("\n--- NAL-NL2 ---\n")
nal_gain  <- get_jd2011_target("a7", "NAL-NL2", hl_freqs, 65)
threshold <- rep(50, 6)
loss <- rep(50, 6)
cat(sprintf("Sones from calc_bramslow_sones: %.2f\n", calc_bramslow_sones(nal_gain, threshold, loss)))

cat("\n--- Open-NL Internal Logic ---\n")
# Copy exactly from open_nl.R lines 141-160
gain_array <- nal_gain
local_loss <- loss
freq <- hl_freqs

ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
aided_spl <- ltass_65 + approx(log10(freq), gain_array, log10(hl_freqs), rule=2)$y - approx(log10(freq), local_loss, log10(hl_freqs), rule=2)$y

f_half <- seq(0, 15000, by = 0.5); f_half[1] <- 1
li <- approx(log10(hl_freqs), aided_spl, log10(f_half), rule = 2)$y
li[f_half < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / pmax(f_half[f_half < hl_freqs[1]], 1))
li[f_half > hl_freqs[6]] <- aided_spl[6] - 24 * log2(f_half[f_half > hl_freqs[6]] / hl_freqs[6])
overall <- 10 * log10(sum(10^(li / 10)) * 0.5)

dense_f <- seq(20, 15000, by = 10)
dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y
dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
dense_l[dense_f > hl_freqs[6]] <- aided_spl[6] - 24 * log2(dense_f[dense_f > hl_freqs[6]] / hl_freqs[6])
current_spl <- 10 * log10(sum(10^(dense_l / 10) * 10))
dense_l <- dense_l + (overall - current_spl)

sn_htl <- pmax(approx(x = log10(freq), y = threshold, xout = log10(hl_freqs), rule = 2)$y - approx(x = log10(freq), y = local_loss, xout = log10(hl_freqs), rule = 2)$y, 0)
ohc_loss <- sn_htl
ihc_loss <- rep(0, length(sn_htl))

loud_res <- calculate_loudness_cpp(inputF = dense_f, inputLdB = dense_l,
          HLcf = hl_freqs, HLohcdB0 = ohc_loss, HLihcdB0 = ihc_loss,
          NoChan = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0)
cat(sprintf("Sones from open_nl logic: %.2f\n", loud_res$Ldn))
