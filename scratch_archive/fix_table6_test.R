profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
out_file <- "table6_output.txt"
cat(sprintf("Length is %d\n", length(profiles)), file=out_file)
for (p in profiles) {
  cat(sprintf("Profile %s\n", p), file=out_file, append=TRUE)
}
cat("\nSUCCESS!\n", file=out_file, append=TRUE)
