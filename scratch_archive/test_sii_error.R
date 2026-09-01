library(SII)
# Create a dummy target
tgt <- structure(list(freq = c(250, 500, 1000, 2000, 4000, 8000), 
                      gain = c(10, 20, 30, 40, 50, 60), 
                      mpo = c(100, 100, 100, 100, 100, 100), 
                      speech = c(50, 50, 50, 50, 50, 50),
                      threshold = c(20, 20, 20, 20, 20, 20),
                      loss = c(0, 0, 0, 0, 0, 0)), 
                 class = "prescription_target")

# Simulate the app.R call exactly
res <- tryCatch({
  sii(speech = tgt$speech, threshold = tgt$threshold, loss = tgt$loss, 
      freq = tgt$freq, prescription = tgt, desensitization = "johnson2011_smoothed")
}, error = function(e) paste("ERROR:", e$message))

print(res)
