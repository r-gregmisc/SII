library(dplyr)
library(ggplot2)
library(parallel)
library(lhs)
library(randomForest)

devtools::load_all(".", quiet=TRUE)
source("R/benchmark_targets.R")

cat("Running Latin Hypercube global sensitivity analysis (approx 30 mins on 8 cores)...\n")

N <- 500
set.seed(42)
X_raw <- randomLHS(N, 7)
# 1. anchor: 0.35 to 0.55
# 2. slope_trigger: 10 to 20
# 3. bypass_onset: 60 to 80
# 4. floor: -20 to 0
# 5. cap_knot_50: 4.5 to 6.5 (affects A4)
# 6. lambda_loud: 500 to 4000
# 7. cr_ceiling: 5.0 to 15.0

X <- data.frame(
  anchor = X_raw[,1] * 0.20 + 0.35,
  slope_trigger = X_raw[,2] * 10 + 10,
  bypass_onset = X_raw[,3] * 20 + 60,
  floor = X_raw[,4] * 20 - 20,
  cap_knot_50 = X_raw[,5] * 2.0 + 4.5,
  lambda_loud = X_raw[,6] * 3500 + 500,
  cr_ceiling = X_raw[,7] * 10.0 + 5.0
)

profiles <- c("a2", "a4", "a5")
results <- list()

for (p in profiles) {
  cat(sprintf("\nEvaluating Profile %s...\n", toupper(p)))
  
  target_data <- jd2011_targets[[tolower(p)]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  
  res_list <- mclapply(1:N, function(i) {
    # Set the global options for the penalties
    cap_knots_65 <- c(7.0, 5.0, X$cap_knot_50[i], 6.5, 6.5)
    if (p == "a5") {
      # For A5, we map cap_knot_50 to the 75-PTA knot (index 4) for variance tracking
      cap_knots_65 <- c(7.0, 5.0, 5.5, X$cap_knot_50[i] + 1.0, 6.5)
    }
    
    options(open_nl_cap_knots_65 = cap_knots_65)
    options(open_nl_lambda_loud = X$lambda_loud[i])
    options(open_nl_cr_ceiling = X$cr_ceiling[i])
    
    # 65 dB constraint needed for variable projection (CR)
    presc_65 <- open_nl(
      speech = 65, threshold = target_data$threshold, loss = rep(0, 6), freq = freqs, 
      optimize = TRUE, enable_severe_booster = TRUE, booster_onset = 60,
      anchor = X$anchor[i], slope_trigger = X$slope_trigger[i], 
      bypass_pta = X$bypass_onset[i], rs_floor = X$floor[i]
    )
    
    obj <- sii(speech="normal", threshold=target_data$threshold, freq=freqs, prescription=presc_65, interpolate=TRUE)
    s_val <- calculate_loudness(presc_65)$total
    
    return(data.frame(
      Profile = toupper(p),
      Anchor = X$anchor[i],
      Trigger = X$slope_trigger[i],
      Bypass = X$bypass_onset[i],
      Floor = X$floor[i],
      CapKnot = X$cap_knot_50[i],
      LambdaLoud = X$lambda_loud[i],
      CRCeiling = X$cr_ceiling[i],
      SII = obj$sii,
      Sones = s_val
    ))
  }, mc.cores = 8)
  
  results[[p]] <- do.call(rbind, res_list)
  
  # Random Forest Variance Partitioning
  cat(sprintf("\n--- Random Forest Variable Importance (Surrogate Sobol Total) for %s ---\n", toupper(p)))
  rf_sii <- randomForest(SII ~ Anchor + Trigger + Bypass + Floor + CapKnot + LambdaLoud + CRCeiling, data=results[[p]], ntree=100)
  imp_sii <- importance(rf_sii)
  imp_sii_pct <- imp_sii / sum(imp_sii) * 100
  print(round(imp_sii_pct[order(-imp_sii_pct), , drop=FALSE], 1))
}

write.csv(do.call(rbind, results), "manuscript_figures/lhs_sensitivity_results.csv", row.names=FALSE)
