# compare_stages.R
# Runs the C++ AUDMOD port on the same inputs and compares every stage with AMT.
# Run from the package root:
#   Rscript reproducibility_scripts/audmod_validation/compare_stages.R

devtools::load_all(quiet = TRUE)

fs <- 32000
N  <- 8192
base <- "reproducibility_scripts/audmod_validation"

cases      <- read.csv(file.path(base, "in/cases_numeric.csv"), header = FALSE)
case_names <- read.csv(file.path(base, "in/case_names.csv"))
stages     <- c("E_0", "E_TQ", "E_UCL", "E_SPL", "E_Vector", "HTLL", "N_prime", "Ldn")

rel_diff <- function(a, b) {
  if (length(a) != length(b)) return(NA_real_)
  max(abs(a - b) / pmax(abs(b), 1e-12))
}

rows <- list()
for (i in seq_len(nrow(cases))) {
  id <- cases[i, 1]
  amt_file <- file.path(base, sprintf("out/amt_%d.csv", id))
  if (!file.exists(amt_file)) next

  amt   <- read.csv(amt_file)
  hl13  <- as.numeric(cases[i, 2:14])
  ucl13 <- as.numeric(cases[i, 15:27])
  P     <- as.numeric(readLines(file.path(base, sprintf("in/spec_%d.csv", id))))

  ref <- audmod_reference_cpp(fs, N, hl13, ucl13)
  res <- audmod_loudness_cpp(P, fs, N, ref)

  cpp <- list(E_0 = ref$E_0, E_TQ = ref$E_TQ, E_UCL = ref$E_UCL,
              E_SPL = res$E_SPL, E_Vector = res$E_Vector, HTLL = res$HTLL,
              N_prime = res$N_prime, Ldn = res$Ldn)

  diffs <- sapply(stages, function(s) {
    reference <- if (s == "Ldn") amt$Ldn[1] else amt[[s]]
    rel_diff(as.numeric(cpp[[s]]), reference)
  })

  rows[[length(rows) + 1]] <- data.frame(
    id = id,
    name = case_names$name[case_names$id == id],
    Ldn_amt = round(amt$Ldn[1], 6),
    Ldn_cpp = round(res$Ldn, 6),
    t(signif(diffs, 3)),
    check.names = FALSE
  )
}

if (length(rows) == 0) stop("No AMT output files found in ", file.path(base, "out"))

out <- do.call(rbind, rows)
print(out, row.names = FALSE)
write.csv(out, file.path(base, "stage_comparison.csv"), row.names = FALSE)

cat("\nLargest relative difference at each stage, across all cases:\n")
print(signif(apply(out[, stages], 2, max, na.rm = TRUE), 3))
cat("\nA faithful port should show values around 1e-10 or smaller.\n")
