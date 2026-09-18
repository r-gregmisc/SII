scripts <- c(
  "gen_budget_decomposition.R",
  "gen_iso_loudness_control.R",
  "gen_desens_sensitivity.R",
  "gen_feasibility_maps.R",
  "gen_multi_level_tables.R",
  "generate_remaining_tables.R",
  "baseline_loudness.R"
)

cat("Running all scripts...\n")
for (s in scripts) {
  cat(sprintf("\n--- Running %s ---\n", s))
  t <- system.time({
    res <- tryCatch(
      system(paste("Rscript", file.path("reproducibility_scripts", s)), intern=TRUE),
      warning = function(w) { print(w); "warning" },
      error = function(e) { print(e); "error" }
    )
  })
  cat(res, sep="\n")
  cat(sprintf("=> Runtime: %.2f seconds\n", t["elapsed"]))
}

cat("\n--- FILES WRITTEN ---\n")
system("ls -1 reproducibility_scripts/output/jaaa_audmod/")

