lines <- readLines("R/open_nl.R")

# Find the block inside `if (isTRUE(optimize)) {`
# Specifically:
# dense_f <- seq(250, 8000, by = 10)
# dense_l <- approx(x = log10(Fi), y = E_aid, xout = log10(dense_f), rule = 2)$y

start_idx <- grep("dense_f <- seq\\(250, 8000, by = 10\\)", lines)

if (length(start_idx) > 0) {
  # Replace the lines with the correct 20-15000 Hz logic that matches sii.R
  new_logic <- c(
    "        dense_f <- seq(20, 15000, by = 10)",
    "        dense_l <- rep(-100, length(dense_f))",
    "        dense_l <- approx(x = log10(Fi), y = E_aid, xout = log10(dense_f), rule = 1)$y",
    "        idx_low <- which(dense_f < Fi[1])",
    "        if (length(idx_low) > 0) {",
    "          octaves_below <- log2(Fi[1] / dense_f[idx_low])",
    "          rolloff_db <- octaves_below * 18.0",
    "          val_at_lowest <- dense_l[length(idx_low) + 1]",
    "          dense_l[idx_low] <- val_at_lowest - rolloff_db",
    "        }",
    "        idx_high <- which(dense_f > Fi[length(Fi)])",
    "        if (length(idx_high) > 0) {",
    "          octaves_above <- log2(dense_f[idx_high] / Fi[length(Fi)])",
    "          rolloff_db <- octaves_above * 18.0",
    "          val_at_highest <- dense_l[length(dense_f) - length(idx_high)]",
    "          dense_l[idx_high] <- val_at_highest - rolloff_db",
    "        }",
    "        dense_l[is.na(dense_l)] <- -100"
  )
  
  lines <- c(lines[1:(start_idx[1]-1)], new_logic, lines[(start_idx[1]+2):length(lines)])
  
  # Also fix the dense_abg bug I accidentally introduced at line 98
  # The bad line: dense_abg <- approx(x = log10(freq), y = local_loss, xout = log10(seq(20, 15000, by = 10)), rule = 2)$y
  # Should be: dense_abg <- approx(x = log10(freq), y = local_loss, xout = log10(dense_f), rule = 2)$y
  # Wait, dense_f at line 98 is currently seq(100, 10000, by=10).
  # Wait, did replace_file_content delete dense_f <- seq(100, 10000, by=10)?
  
  writeLines(lines, "R/open_nl.R")
  cat("Patched!\n")
} else {
  cat("Could not find the target lines.\n")
}
