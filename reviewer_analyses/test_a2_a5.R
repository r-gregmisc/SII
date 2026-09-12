devtools::load_all(".")

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
threshold_A2 <- c(60, 50, 30, 20, 20, 20)
threshold_A5 <- c(75, 75, 80, 90, 100, 110)

run_experiment <- function(profile_name, threshold_vec) {
  cat(sprintf("\n=== Evaluating Profile %s ===\n", profile_name))
  losses <- numeric(20)
  g1k <- numeric(20)
  g4k <- numeric(20)
  
  for (i in 1:20) {
    set.seed(i)
    tgt <- suppressWarnings(suppressMessages(open_nl(speech = 65, threshold = threshold_vec, freq = freqs, optimize=TRUE, seed_noise=25)))
    losses[i] <- last_best_loss
    g1k[i] <- tgt$gain[3]
    g4k[i] <- tgt$gain[5]
  }
  
  cat(sprintf("Loss Distribution: Mean = %.2f, SD = %.2f, Range = [%.2f, %.2f]\n", mean(losses), sd(losses), min(losses), max(losses)))
  cat(sprintf("Variance in 1kHz Gain: %.2f dB^2\n", var(g1k)))
  cat(sprintf("Variance in 4kHz Gain: %.2f dB^2\n", var(g4k)))
  # print(losses)
}

run_experiment("A2", threshold_A2)
run_experiment("A5", threshold_A5)
run_experiment("A4", c(65, 65, 70, 75, 80, 85))

