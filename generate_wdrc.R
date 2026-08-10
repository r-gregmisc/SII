library(devtools)
load_all()

profiles <- list(
  a1 = c(15, 20, 30, 40, 50, 60),
  a2 = c(60, 50, 40, 30, 20, 15),
  a3 = c(10, 20, 40, 50, 55, 60),
  a4 = c(0, 0, 10, 40, 70, 80),
  a5 = c(10, 10, 20, 60, 80, 100),
  a6 = c(50, 55, 60, 65, 75, 80), # Mixed (needs ABG, we'll use HTL for now or use loss)
  a7 = c(50, 50, 50, 50, 50, 50)  # Cond (needs ABG, we'll use HTL for now)
)

results <- data.frame(Profile = character(), Level = numeric(), SII = numeric(), Sones = numeric(), stringsAsFactors = FALSE)

for (p in names(profiles)) {
  htl <- profiles[[p]]
  # Basic assumptions for A6 and A7 based on Johnson & Dillon
  abg <- rep(0, 6)
  if (p == "a6") abg <- c(30, 30, 30, 30, 30, 30)
  if (p == "a7") abg <- c(50, 50, 50, 50, 50, 50)
  
  for (lvl in c(50, 65, 80)) {
    targets <- sii(htl, abg=abg, level=lvl)
    sii_val <- targets$sii
    # Get loudness
    lt <- targets$loudness_target
    loud_val <- sum(lt$specific_loudness) # sum of sones/ERB across ERBs, approximate sones
    # We actually need to use the `evaluate_loudness` function if it exists, or just sum it.
    
    results <- rbind(results, data.frame(Profile = p, Level = lvl, SII = round(sii_val, 2), Sones = round(loud_val, 2)))
  }
}

write.csv(results, "wdrc_results.csv", row.names = FALSE)
