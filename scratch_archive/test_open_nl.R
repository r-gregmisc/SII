devtools::load_all(".")
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
threshold <- rep(50, 6)
loss <- rep(50, 6)

cat("Testing calculate_open_nl_gain for A7:\n")
gain <- calculate_open_nl_gain(freq=hl_freqs, threshold=threshold, input_level=65, loss=loss)
print(gain)

