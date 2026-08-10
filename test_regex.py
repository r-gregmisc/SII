import re

code = """
  lf_penalty_max <- 0
  if (slope_diff > 15) {
    # STEEP SLOPE: Aggressive penalty to low-frequency gain
    # to prevent the overall loudness density from exceeding the comfort threshold (fixes A5 overprescription).
    lf_penalty_factor <- pmin(1, (slope_diff - 15) / 20)
    lf_penalty_max <- lf_penalty_factor * 15 # Up to 15 dB penalty
    
    lf_weights <- pmax(0, 1 - (log10(freq) - log10(250)) / log10(1000/250))
    g_base <- g_base - (lf_penalty_max * lf_weights)
  }
"""

thresh = 30
pen = 15

# gsub("if \\(slope_diff > 15\\) \\{", sprintf("if (slope_diff > %d) {", thresh), mod_file)
code = re.sub(r'if \(slope_diff > 15\) \{', f'if (slope_diff > {thresh}) {{', code)

# gsub("lf_penalty_factor <- pmin\\(1, \\(slope_diff - 15\\) / 20\\)", sprintf("lf_penalty_factor <- pmin(1, (slope_diff - %d) / 20)", thresh), mod_file)
code = re.sub(r'lf_penalty_factor <- pmin\(1, \(slope_diff - 15\) / 20\)', f'lf_penalty_factor <- pmin(1, (slope_diff - {thresh}) / 20)', code)

# gsub("lf_penalty_max <- lf_penalty_factor \\* 15 #", sprintf("lf_penalty_max <- lf_penalty_factor * %d #", pen), mod_file)
code = re.sub(r'lf_penalty_max <- lf_penalty_factor \* 15 #', f'lf_penalty_max <- lf_penalty_factor * {pen} #', code)

print(code)
