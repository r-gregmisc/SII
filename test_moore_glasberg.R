library(devtools)
load_all()

# Override calculate_loudness_chen2011 locally for the test
source("R/moore_glasberg.R")
calculate_loudness_chen2011 <- function(...) {
    # We will redefine the function with the fix to check its behavior.
    # Actually, R's namespace makes it easier to just use `assignInNamespace` or we just patch the file directly.
}
