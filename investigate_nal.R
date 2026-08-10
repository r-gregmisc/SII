library(devtools)
load_all()

# Load the A5 profile
freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
a5_hl <- c(60, 65, 70, 75, 85, 90, 95, 95)

# We need the pre-extracted NAL-NL2 gain for A5 from the package data or somewhere.
# Wait, how does generate_tradeoff.R calculate the NAL-NL2 loudness?
