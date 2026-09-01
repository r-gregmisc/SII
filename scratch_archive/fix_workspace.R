cat("Checking Global Environment for conflicts...\n")
bad_vars <- intersect(ls(envir = .GlobalEnv), c("open_nl", "sii", "calculate_loudness", "critical", "octave"))
if (length(bad_vars) > 0) {
  cat("FOUND CONFLICTING VARIABLES IN GLOBAL ENV:\n")
  print(bad_vars)
} else {
  cat("No conflicting variables found.\n")
}
