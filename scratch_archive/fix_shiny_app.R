lines <- readLines("inst/shiny/app.R")
start_idx <- grep("calc_amt_loudness <- function\\(gain_tgt, htl, cond, target_level\\)", lines)
end_idx <- grep("return\\(loudness_res\\$Ldn\\)", lines) + 1 # finding the end of the function

new_func <- c(
"    # Use exact command-line calculate_binaural_loudness to unify Shiny and command-line",
"    calc_amt_loudness <- function(gain_tgt, htl, cond, target_level) {",
"      freqs <- c(250, 500, 1000, 2000, 4000, 8000)",
"      # Use the 6-band speech spectrum",
"      if (!exists(\"critical\", envir = .GlobalEnv)) {",
"        data(\"critical\", package=\"SII\", envir = .GlobalEnv)",
"      }",
"      normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y",
"      overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))",
"      speech_spec <- normal_speech + (target_level - overall_normal)",
"      ",
"      sii_obj <- sii(speech=speech_spec, threshold=htl, loss=cond, freq=freqs, method=\"octave\", transducer=\"none\", custom_gain=gain_tgt, desensitization=FALSE)",
"      return(calculate_binaural_loudness(sii_obj))",
"    }"
)

lines <- c(lines[1:(start_idx-2)], new_func, lines[(end_idx+1):length(lines)])
writeLines(lines, "inst/shiny/app.R")
