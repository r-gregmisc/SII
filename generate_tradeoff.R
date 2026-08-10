library(devtools)
load_all()

df <- read.csv("tradeoff_results_corrected.csv", stringsAsFactors = FALSE)

a_profiles <- list(
  A1 = c(10, 10, 15, 25, 45, 55, 65, 70),
  A2 = c(20, 20, 25, 35, 45, 50, 50, 50),
  A3 = c(30, 35, 40, 45, 55, 60, 65, 70),
  A4 = c(50, 50, 55, 65, 70, 75, 80, 80),
  A5 = c(60, 65, 70, 75, 85, 90, 95, 95),
  A6 = c(25, 30, 35, 40, 50, 55, 60, 65),
  A7 = c(10, 10, 15, 25, 45, 55, 65, 70)
)
losses <- list(
  A1 = rep(0, 8), A2 = rep(0, 8), A3 = rep(0, 8), A4 = rep(0, 8), A5 = rep(0, 8),
  A6 = c(15, 15, 15, 15, 15, 15, 15, 15),
  A7 = c(10, 10, 15, 25, 45, 55, 65, 70)
)
freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)

for (p in names(a_profiles)) {
  s <- sii(speech = "normal", threshold = a_profiles[[p]], loss = losses[[p]], freq = freqs, prescription = "Open-NL", experience = "experienced", interpolate = TRUE)
  l <- calculate_loudness(s)
  
  idx <- which(df$Audiogram == p & df$Formula == "Open-NL")
  df$SII[idx] <- round(s$sii, 2)
  df$Sones[idx] <- round(l, 1)
}

write.csv(df, "tradeoff_results_corrected.csv", row.names=FALSE)
cat("Updated tradeoff_results_corrected.csv successfully!\n")

# Generate the tradeoff_plot.png
library(ggplot2)
library(ggrepel)
png("tradeoff_plot.png", width=2400, height=1800, res=300)
p <- ggplot(df, aes(x = Sones, y = SII, color = Formula, label = paste(Audiogram, Formula, sep="-"))) +
  geom_point(size = 3) +
  geom_text_repel(size = 2.5, max.overlaps = 50) +
  theme_bw() +
  labs(x = "Predicted Monaural Loudness (Sones)", y = "Speech Intelligibility Index (SII)", 
       title = "Theoretical SII vs Monaural Loudness (A1-A7 Profiles)")
print(p)
dev.off()
cat("Updated tradeoff_plot.png successfully!\n")

# Inject the updated table directly into the manuscript
md_lines <- readLines("OpenNL_manuscript.md")
table_start <- grep("^\\| Audiogram \\| Prescription \\|", md_lines)
if (length(table_start) > 0) {
  # Build new table
  new_table <- c(
    "| Audiogram | Prescription | SII | Loudness (Sones) |",
    "| :--- | :--- | :--- | :--- |"
  )
  for (i in 1:nrow(df)) {
    new_table <- c(new_table, sprintf("| %s | %s | %.2f | %.1f |", 
                                      df$Audiogram[i], df$Formula[i], df$SII[i], df$Sones[i]))
  }
  # Find end of table (first empty line after table_start)
  table_end <- table_start + 1
  while(table_end <= length(md_lines) && grepl("^\\|", md_lines[table_end])) {
    table_end <- table_end + 1
  }
  md_lines <- c(md_lines[1:(table_start-1)], new_table, md_lines[table_end:length(md_lines)])
  writeLines(md_lines, "OpenNL_manuscript.md")
  cat("Updated Table I in OpenNL_manuscript.md successfully!\n")
}
