mod_file <- readLines("R/nalr.R")
matches <- grep("g_base <- g_base \\+ 0\\.15 \\* pmax\\(0, sn_threshold - 60\\)", mod_file)
cat("Matches:", length(matches), "\n")
if (length(matches) > 0) cat("Line:", mod_file[matches[1]], "\n")
