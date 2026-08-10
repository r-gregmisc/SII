library(devtools)
load_all()
profiles = list(A1 = c(15, 20, 30, 40, 50, 60))
abg_list = list(A1 = rep(0, 6))
freqs = c(250, 500, 1000, 2000, 4000, 8000)

tryCatch({
  tgt = open_nl(65, threshold=profiles$A1, freq=freqs, loss=abg_list$A1)
  print(tgt$G_65)
}, error = function(e) {
  print(e)
})
