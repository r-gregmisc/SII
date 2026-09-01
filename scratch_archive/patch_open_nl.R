lines <- readLines("R/open_nl.R")
idx <- grep("error = function\\(e\\) NULL", lines)
if (length(idx) > 0) {
  lines[idx] <- "      }, error = function(e) { message(\"C++ ERROR: \", conditionMessage(e)); return(NULL) })"
  writeLines(lines, "R/open_nl.R")
  cat("Patched open_nl.R to print C++ errors\n")
} else {
  cat("Could not find line to patch\n")
}
