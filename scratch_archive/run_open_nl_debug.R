source("R/sii.R")
source("R/open_nl.R")
source("R/nalr.R")

freq <- c(250, 500, 1000, 2000, 4000, 8000)
threshold <- c(15, 20, 30, 40, 50, 60)

res <- open_nl(speech=65, threshold=threshold, freq=freq)
print(round(res$gain, 1))

