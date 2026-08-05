source("R/moore_glasberg.R")
source("R/nalr.R")
source("R/sii.R")

freq <- c(250, 500, 1000, 2000, 4000, 8000)
threshold <- c(15, 20, 30, 40, 50, 60) # A-1
speech <- "normal"
loss <- rep(0, 6)

res_opennl <- sii(speech=speech, threshold=threshold, loss=loss, freq=freq, prescription="Open-NL", experience="experienced")
cat(sprintf("Open-NL Loudness: %.1f sones\n", res_opennl$loudness))

