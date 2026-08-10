library(SII)
freqs <- c(250, 500, 1000, 2000, 4000, 8000)
a4_hl <- c(65, 70, 75, 80, 85, 90)

# Calculate Open-NL
ig_opennl <- SII:::calculate_open_nl_gain(a4_hl, freqs, input_spl=65)

# NAL-NL2 (mocked from Johnson & Dillon, or we can see what the package has)
cat("Open-NL IG:", ig_opennl, "\n")
