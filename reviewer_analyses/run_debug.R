devtools::load_all(".")
freqs <- c(250, 500, 1000, 2000, 4000, 8000)
threshold_A2 <- c(60, 50, 30, 20, 20, 20)
tgt <- suppressWarnings(suppressMessages(open_nl(speech = 65, threshold = threshold_A2, freq = freqs, optimize=TRUE)))
