lines <- readLines("generate_a1_a7.R")
lines <- gsub('prescription="Open-NL"', 'prescription=NULL', lines)
writeLines(lines, "generate_a1_a7.R")
