## This file tests the Open-NL prescription logic, specifically ensuring
## that mixed and conductive hearing losses mathematically respect the
## Air-Bone Gap rules and absolute MPO caps.

library(SII)

# A-7 Preset (Flat 50 dB Conductive Loss)
# All AC thresholds are 50 dB HL. All BC thresholds are 0 dB HL.
# Therefore, sn_threshold is 0 dB HL.
data("critical", package="SII")
freq_21 <- critical$fi
htl_21 <- rep(50, 21)
loss_21 <- rep(50, 21)
normal_speech <- critical$normal

# 1. Gain Calculation Test
# For a 0 dB SN loss, WDRC shaping should yield negative gain in low/high frequencies,
# before the 37.5 dB linear ABG compensation is added.
# So the final insertion gain at 250 Hz MUST be strictly less than 37.5 dB.
gain <- SII:::calculate_open_nl_gain(
  freq = freq_21,
  threshold = htl_21,
  loss = loss_21,
  input_level = 65
)

# Test that the low-frequency WDRC roll-off successfully survived the calculation
stopifnot(gain[1] < 37.5)
# Test that gain is overall positive for a 50dB conductive loss
stopifnot(gain[1] > 0)


# 2. MPO Limits Test
# The A-6 Mixed loss has a max threshold of 90 dB HL at 8000 Hz, with 40 dB BC.
htl_a6 <- c(35, 35, 40, 50, 60, 60, 60, 65, 75, 80, 85, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90)
loss_a6 <- c(10, 10, 10, 15, 20, 20, 20, 25, 35, 40, 45, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50)
mpo <- SII:::calculate_nal_sspl90(
  freq = freq_21,
  threshold = htl_a6,
  gain = rep(0, length(htl_a6)),
  loss = loss_a6
)

# Ensure no MPO exceeds the absolute hardware cap of 135 dB SPL
stopifnot(all(mpo <= 135))


# 3. SII Engine Integration Test
# Ensure that calling sii() with `prescription = "Open-NL"` and `loss` doesn't crash,
# and successfully calculates a mathematically valid SII index.
res <- sii(
  speech = normal_speech,
  threshold = htl_21,
  loss = loss_21,
  freq = freq_21,
  prescription = "Open-NL",
  method = "critical"
)

# Check that the returned SII is a valid number between 0 and 1
stopifnot(is.numeric(res$sii))
stopifnot(res$sii >= 0 && res$sii <= 1.0)

print("All Open-NL Conductive/Mixed Loss unit tests passed successfully!")

# Test Infant RECD application
gain_adult <- SII:::calculate_open_nl_gain(
  freq = freq_21,
  threshold = htl_a6,
  input_level = 65,
  age = "adult"
)

gain_infant <- SII:::calculate_open_nl_gain(
  freq = freq_21,
  threshold = htl_a6,
  input_level = 65,
  age = "child_0_5"
)

# Infant should have LESS insertion gain prescribed because the smaller ear canal
# will naturally produce MORE real-ear SPL for the same coupler output.
# We check the mid-frequencies (e.g., 1000 Hz) to avoid the high-frequency 
# bandwidth roll-off differences between infants and adults confounding the check.
idx_1k <- which(freq_21 == 1000)
if (gain_infant[idx_1k] < gain_adult[idx_1k]) {
  print("Infant RECD gain reduction successfully applied!")
} else {
  stop("Infant RECD failed to reduce gain appropriately.")
}
