library(devtools)
load_all()
source("R/benchmark_targets.R")

cat("\n--- NAL-NL2 JD Gain Checks ---\n")
jd_a4_gain <- get_jd2011_target("a4", "NAL-NL2", c(250, 500, 1000, 2000, 4000, 8000))
cat("A4 NAL-NL2 Target Gain:", jd_a4_gain, "\n")

jd_a5_gain <- get_jd2011_target("a5", "NAL-NL2", c(250, 500, 1000, 2000, 4000, 8000))
cat("A5 NAL-NL2 Target Gain:", jd_a5_gain, "\n")
