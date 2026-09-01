amt_matlab <- c(4.15, 6.02, 3.51, 4.47, 3.65, 6.45, 6.56, 6.22, 5.52, 6.34, 2.10, 3.72, 3.09, 3.21)
cpp_rcpp <- c(4.3, 7.3, 3.4, 6.0, 3.9, 7.0, 6.1, 7.9, 5.5, 7.0, 2.1, 3.0, 1.2, 1.0)
labels <- c("A1 NAL", "A1 Open", "A2 NAL", "A2 Open", "A3 NAL", "A3 Open", "A4 NAL", "A4 Open", "A5 NAL", "A5 Open", "A6 NAL", "A6 Open", "A7 NAL", "A7 Open")

errors <- abs(amt_matlab - cpp_rcpp)
mae <- mean(errors)
mae_no_a7 <- mean(errors[1:12])

cat(sprintf("Overall MAE: %.3f sones\n", mae))
cat(sprintf("MAE (excluding A7): %.3f sones\n\n", mae_no_a7))

cat(sprintf("%-10s | %-8s | %-8s | %-8s\n", "Profile", "MATLAB", "C++", "Error"))
cat("--------------------------------------------\n")
for (i in 1:length(labels)) {
  cat(sprintf("%-10s | %-8.2f | %-8.2f | %-8.2f\n", labels[i], amt_matlab[i], cpp_rcpp[i], errors[i]))
}
