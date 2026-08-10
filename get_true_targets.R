library(devtools)
load_all()

# Get benchmark targets for NAL-NL2, DSL, CAMEQ2-HF at 65 dB
source("R/benchmark_targets.R")

cat("Profile,Formula,Level,SII,Sones\n")

for (p in names(jd2011_targets)) {
  htl <- jd2011_targets[[p]]$threshold
  abg <- rep(0, 6)
  if (!is.null(jd2011_targets[[p]]$loss)) abg <- htl - jd2011_targets[[p]]$loss

  # Open-NL at 50, 65, 80
  for (lvl in c(50, 65, 80)) {
    res <- sii(htl, abg=abg, level=lvl)
    sii_val <- res$sii
    lt <- res$loudness_target
    loud_val <- sum(lt$specific_loudness)
    cat(sprintf("%s,Open-NL,%d,%.2f,%.1f\n", p, lvl, sii_val, loud_val))
  }
}
