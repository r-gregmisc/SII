
original_file <- c("g_base <- g_base + 0.15 * pmax(0, sn_threshold - 60)")

for (bp in c(70, 80)) {
  for (sl in c(0.0, 0.2)) {
    mod_file <- original_file
    mod_file <- gsub("g_base <- g_base \\+ 0\\.15 \\* pmax\\(0, sn_threshold - 60\\)", 
                     sprintf("g_base <- g_base + %f * pmax(0, sn_threshold - %d)", sl, bp), 
                     mod_file)
    cat(sprintf("bp=%d sl=%.1f -> %s\n", bp, sl, mod_file))
  }
}
