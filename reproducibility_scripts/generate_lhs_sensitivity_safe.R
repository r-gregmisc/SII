library(dplyr)
library(ggplot2)
library(parallel)
library(lhs)
library(randomForest)

devtools::load_all(".", quiet=TRUE)
source("R/benchmark_targets.R")

cat("Running Latin Hypercube global sensitivity analysis (Safe PSOCK Cluster)...\n")

N <- 150
set.seed(42)
X_raw <- randomLHS(N, 7)

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

cl <- makeCluster(detectCores() - 1)
clusterEvalQ(cl, {
  devtools::load_all(".", quiet=TRUE)
  source("R/benchmark_targets.R")
})
clusterExport(cl, c("X", "profiles", "N"))

for (p in profiles) {
  cat(sprintf("\nEvaluating Profile %s (N=%d)...\n", toupper(p), N))
  
  target_data <- jd2011_targets[[tolower(p)]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  
  clusterExport(cl, c("p", "target_data", "freqs"))
  
  res_list <- parLapply(cl, 1:N, function(i) {
    # Set the global options for the penalties inside the worker
    cap_knots_65 <- c(7.0, 5.0, X$cap_knot_50[i], 6.5, 6.5)
    if (p == "a5") {
      cap_knots_65 <- c(7.0, 5.0, 5.5, X$cap_knot_50[i] + 1.0, 6.5)
    }
    
    options(open_nl_cap_knots_65 = cap_knots_65)
    options(open_nl_lambda_loud = X$lambda_loud[i])
    options(open_nl_cr_ceiling = X$cr_ceiling[i])
    
    # Run Open-NL
    presc_65 <- tryCatch({
      open_nl(
        speech = 65, threshold = target_data$threshold, loss = rep(0, 6), freq = freqs, 
        optimize = TRUE, enable_severe_booster = TRUE, booster_onset = 60,
        anchor = X$anchor[i], slope_trigger = X$slope_trigger[i], 
        bypass_pta = X$bypass_onset[i], rs_floor = X$floor[i]
      )
    }, error = function(e) NULL)
    
    if (is.null(presc_65)) return(NULL)
    
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
  })
  
  res_list <- Filter(Negate(is.null), res_list)
  results[[p]] <- do.call(rbind, res_list)
  
  # Random Forest Variance Partitioning
  cat(sprintf("\n--- Random Forest Variable Importance (Surrogate Sobol Total) for %s ---\n", toupper(p)))
  rf_sii <- randomForest(SII ~ Anchor + Trigger + Bypass + Floor + CapKnot + LambdaLoud + CRCeiling, data=results[[p]], ntree=100)
  imp_sii <- importance(rf_sii)
  imp_sii_pct <- imp_sii / sum(imp_sii) * 100
  print(round(imp_sii_pct[order(-imp_sii_pct), , drop=FALSE], 1))
}

stopCluster(cl)
write.csv(do.call(rbind, results), "manuscript_figures/lhs_sensitivity_results.csv", row.names=FALSE)
