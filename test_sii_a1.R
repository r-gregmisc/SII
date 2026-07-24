library(SII)
freq <- c(250, 500, 1000, 2000, 4000, 8000)
threshold <- c(50, 50, 50, 50, 50, 50)
data(critical)

source("R/nalr.R")

# NAL-R gain
ig_nalr <- calculate_nalr_gain(freq, threshold)

# Open-NL gain (55 dB)
ig_opennl_55 <- calculate_open_nl_gain(freq, threshold, input_level=critical$normal-10, experience="experienced")

print("NAL-R Gain:")
print(ig_nalr)

print("Open-NL Gain for 55:")
print(ig_opennl_55)
