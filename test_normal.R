library(devtools)
load_all()

s <- sii(speech="normal")
l <- calculate_loudness(s)
cat(sprintf("Normal loudness: %.2f sones\n", l))
