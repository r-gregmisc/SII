devtools::load_all(".")

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
threshold_A2 <- c(60, 50, 30, 20, 20, 20)

# We want to see if sii() inside obj_fn is failing. We can just add print statements to open_nl.R
lines <- readLines("R/open_nl.R")
insert_idx <- grep("if \\(is.null\\(res\\)\\)", lines)
lines <- append(lines, "        if (is.null(res)) cat('sii() failed!\\n')", after = insert_idx - 1)
writeLines(lines, "R/open_nl.R")
