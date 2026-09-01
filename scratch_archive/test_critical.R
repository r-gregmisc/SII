suppressPackageStartupMessages(devtools::load_all("."))
tryCatch({
  print(head(critical))
}, error = function(e) print(e))
