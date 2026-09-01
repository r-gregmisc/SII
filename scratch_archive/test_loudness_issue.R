devtools::load_all(".")
load("data/critical.rda")
f_21 <- critical$fi
threshold <- jd2011_targets$a1$threshold
loss <- rep(0, 6)
htl_21 <- approx(x=log10(c(250, 500, 1000, 2000, 4000, 8000)), y=threshold, xout=log10(f_21), rule=2)$y

target_level <- 65
overall_normal <- 62.35
speech_input <- critical$normal + (target_level - overall_normal)
target_nalnl2 <- get_nalnl2_v2_target("a1", "NAL-NL2", f_21, target_level)

obj_nalnl2 <- sii(speech = speech_input, threshold = htl_21, freq = f_21, custom_gain = target_nalnl2, desensitization = "none")

cat("NAL-NL2 Sones:", calculate_loudness(obj_nalnl2)$total, "\n")
