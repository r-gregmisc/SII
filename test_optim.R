r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
for (f in r_files) source(f)

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
thresholds <- c(10, 10, 20, 60, 80, 100) # A5

t0 <- Sys.time()
res <- open_nl(speech = 65, threshold = thresholds, freq = freqs)
t1 <- Sys.time()

print(t1 - t0)
print(res$gain)

# Now manually run optim to see if it works
obj_fn <- function(gain_array) {
    temp_target <- list(
    freq = freqs,
    gain = gain_array,
    mpo = res$mpo,
    speech = res$speech,
    threshold = thresholds,
    loss = rep(0, length(freqs)),
    module = "standard",
    overall_level = 65
    )
    class(temp_target) <- "prescription_target"
    
    sii_res <- sii(speech = res$speech + gain_array, noise = rep(-50, length(freqs)), 
        threshold = thresholds, loss = rep(0, length(freqs)), freq = freqs, 
        prescription = temp_target, interpolate = FALSE)
    
    sones <- calculate_loudness(sii_res)
    score <- sii_res$sii
    if (sones > 20) {
        score <- score - (sones - 20) * 10
    }
    return(-score)
}

t2 <- Sys.time()
opt <- optim(par = res$gain, fn = obj_fn, method = "L-BFGS-B", lower = rep(0, length(freqs)), upper = rep(80, length(freqs)))
t3 <- Sys.time()

print(t3 - t2)
print(opt$par)

