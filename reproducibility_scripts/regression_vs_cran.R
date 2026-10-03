## regression_vs_cran.R ---------------------------------------------------------------
## Checks that the standard SII calculation in this version of the package is
## unchanged from the original CRAN release of SII (Warnes), when none of the new
## options (desensitization, prescriptions, etc.) is used.
##
## 1. Installs the CRAN release into a temporary library (not your main library).
## 2. Runs the same cases through the CRAN release and through this repository
##    (devtools::load_all), each in its own R process so the two never collide:
##      - the 8 official test cases from the ANSI S3.5 developer kit
##        (tests/test_sii.R), with their published answers;
##      - the vignette examples (Annex C.1 and C.2, left and right ear with
##        interpolation);
##      - 200 random cases covering every method, speech level, importance
##        function and the interpolate option.
## 3. Compares the SII and every column of the band table.
##
## Run from the repo root (needs internet once, for the CRAN download):
##   source("reproducibility_scripts/regression_vs_cran.R")
## ---------------------------------------------------------------------------------------

if (!requireNamespace("callr", quietly = TRUE)) install.packages("callr")

## Two reference versions: the current CRAN release and the newest 1.0.x release
## in the CRAN archive (the original Warnes package). Each goes in its own
## temporary library, never your main library.
arch_url <- "https://cran.r-project.org/src/contrib/Archive/SII/"
arch <- readLines(arch_url, warn = FALSE)
tgzs <- unique(regmatches(arch, regexpr("SII_[0-9.\\-]+\\.tar\\.gz", arch)))
vers <- sub("SII_(.*)\\.tar\\.gz", "\\1", tgzs)
cat("Versions in the CRAN archive:", paste(vers, collapse = ", "), "\n")
v10 <- vers[grepl("^1\\.0", vers)]
v10 <- v10[order(package_version(v10), decreasing = TRUE)][1]

install_ref <- function(label, tarball = NULL) {
  lib <- file.path(tempdir(), paste0("sii_ref_", label)); dir.create(lib, showWarnings = FALSE)
  if (!file.exists(file.path(lib, "SII", "DESCRIPTION"))) {
    if (is.null(tarball)) install.packages("SII", lib = lib, repos = "https://cloud.r-project.org", quiet = TRUE)
    else install.packages(paste0(arch_url, tarball), lib = lib, repos = NULL, type = "source", quiet = TRUE)
  }
  d <- read.dcf(file.path(lib, "SII", "DESCRIPTION"))
  cat(sprintf("Reference %-8s SII %s, maintainer: %s\n", label, d[, "Version"],
              if ("Maintainer" %in% colnames(d)) d[, "Maintainer"] else "?"))
  lib
}
refs <- list(cran = install_ref("cran"))
if (!is.na(v10)) refs$original <- install_ref("original", paste0("SII_", v10, ".tar.gz"))

## ---- the cases ------------------------------------------------------------------------
make_cases <- function() {
  cs <- list(
    OCTAVE   = list(speech = c(50,40,40,30,20,0), noise = c(70,65,45,25,1,-15),
                    threshold = c(0,0,0,0,0,7.1), method = "octave"),
    OCTAVE_1 = list(speech = c(50,40,40,30,20,0), noise = c(70,65,45,25,1,-15),
                    threshold = c(0,0,0,0,0,7.1), importance = c(0,0,1,0,0,0), method = "octave"),
    TO       = list(speech = c(90,5,rep(40,12),rep(-10,4)),
                    noise = c(10,-10,-10,75,rep(-10,10),rep(10,4)),
                    threshold = c(90,rep(0,17)), method = "one-third octave"),
    TO_1     = list(speech = c(90,5,rep(40,12),rep(-10,4)),
                    noise = c(10,-10,-10,75,rep(-10,10),rep(10,4)),
                    threshold = c(90,rep(0,17)),
                    importance = c(rep(0,9),rep(0.1,7),0.3,0), method = "one-third octave"),
    CB       = list(speech = c(-10,-10,-10,90,5,rep(40,12),rep(-10,4)),
                    noise = c(10,10,10,10,-10,-10,70,rep(-10,10),rep(10,4)),
                    threshold = c(0,0,0,90,rep(0,17))),
    CB_1     = list(speech = c(-10,-10,-10,90,5,rep(40,12),rep(-10,4)),
                    noise = c(10,10,10,10,-10,-10,70,rep(-10,10),rep(10,4)),
                    threshold = c(0,0,0,90,rep(0,17)),
                    importance = c(rep(0,10),rep(0.1,7),0.3,0,0,0)),
    ECB      = list(speech = c(-10,90,5,rep(40,12),-10,-10),
                    noise = c(10,10,-10,-10,70,rep(-10,10),10,10),
                    threshold = c(0,90,rep(0,15)), method = "equal-contributing"),
    ECB_1    = list(speech = c(-10,90,5,rep(40,12),-10,-10),
                    noise = c(10,10,-10,-10,70,rep(-10,10),10,10),
                    threshold = c(0,90,rep(0,15)),
                    importance = c(rep(0,8),rep(0.1,7),0.3,0), method = "equal-contributing"),
    AnnexC1  = list(speech = c(50,40,40,30,20,0), noise = c(70,65,45,25,1,-15),
                    threshold = rep(0,6), method = "octave", importance = "CST"),
    AnnexC2  = list(speech = rep(54,18), noise = c(40,30,20,rep(0,15)),
                    threshold = rep(0,18), method = "one-third"),
    LeftEar  = list(speech = "raised", threshold = c(25,25,30,35,45,45,55,60),
                    freq = c(250,500,1000,2000,3000,4000,6000,8000),
                    importance = "NU6", interpolate = TRUE),
    RightEar = list(speech = "raised", threshold = c(15,15,20,25,35,35,45,50),
                    freq = c(250,500,1000,2000,3000,4000,6000,8000),
                    importance = "NU6", interpolate = TRUE))
  set.seed(20261001)
  nb <- c(critical = 21, "equal-contributing" = 17, "one-third octave" = 18, octave = 6)
  imps <- c("SII","NNS","CID22","NU6","DRT","ShortPassage","SPIN","CST")
  for (i in 1:200) {
    m <- sample(names(nb), 1); n <- nb[[m]]
    sp <- if (runif(1) < 0.5) sample(c("normal","raised","loud","shout"), 1) else round(runif(n, -10, 80), 1)
    imp <- if (m %in% c("critical","one-third octave","octave")) sample(imps, 1) else "SII"
    if (runif(1) < 0.25) {        # measured audiogram, interpolated (critical band method)
      cs[[sprintf("rand%03d", i)]] <- list(speech = sp[1], method = "critical", importance = "SII",
        threshold = round(runif(8, 0, 90)), freq = c(250,500,1000,2000,3000,4000,6000,8000),
        interpolate = TRUE)
      if (!is.character(sp)) cs[[sprintf("rand%03d", i)]]$speech <- "normal"
    } else {
      cs[[sprintf("rand%03d", i)]] <- list(speech = sp, method = m, importance = imp,
        noise = round(runif(n, -20, 70), 1), threshold = round(runif(n, -5, 100), 1))
    }
  }
  cs
}

run_cases <- function(cases) {
  lapply(cases, function(a) tryCatch({
    r <- do.call(SII::sii, a)
    list(sii = r$sii, table = as.data.frame(r$table, check.names = FALSE))
  }, error = function(e) list(error = conditionMessage(e))))
}

cases <- make_cases()
cat("Running the cases through this repository ...\n")
new <- callr::r(function(cases, run_cases, root) {
  suppressMessages(devtools::load_all(root, quiet = TRUE)); run_cases(cases)
}, args = list(cases = cases, run_cases = run_cases, root = normalizePath(".")))
`%||%` <- function(a, b) if (is.null(a)) b else a
official <- c(OCTAVE = 0.491, OCTAVE_1 = 0.323, TO = 0.445, TO_1 = 0.438,
              CB = 0.273, CB_1 = 0.410, ECB = 0.278, ECB_1 = 0.410)

for (lab in names(refs)) {
  cat(sprintf("\nRunning the cases through reference '%s' ...\n", lab))
  old <- callr::r(function(cases, run_cases, lib) {
    .libPaths(c(lib, .libPaths())); library(SII, lib.loc = lib); run_cases(cases)
  }, args = list(cases = cases, run_cases = run_cases, lib = refs[[lab]]))

  cat(sprintf("\n==== [%s] Official developer-kit cases (published / reference / this version) ====\n", lab))
  for (nm in names(official))
    cat(sprintf("  %-9s %.3f   %.4f   %.4f   %s\n", nm, official[[nm]], old[[nm]]$sii %||% NA,
                new[[nm]]$sii, if (round(new[[nm]]$sii, 3) == official[[nm]]) "OK" else "MISMATCH"))

  cat(sprintf("\n==== [%s] All cases: this version vs reference ====\n", lab))
  max_dsii <- 0; errs <- character(0); coldiff <- list(); ndiff <- 0; nsii <- 0
  for (nm in names(cases)) {
    o <- old[[nm]]; n <- new[[nm]]
    if (!is.null(o$error) || !is.null(n$error)) {
      if (!identical(o$error, n$error))
        errs <- c(errs, sprintf("%s: reference %s | new %s", nm, o$error %||% "ok", n$error %||% "ok"))
      next
    }
    d <- abs(o$sii - n$sii); max_dsii <- max(max_dsii, d); if (d > 1e-10) nsii <- nsii + 1
    common <- intersect(names(o$table), names(n$table))
    num <- common[sapply(common, function(cl) is.numeric(o$table[[cl]]))]
    hit <- FALSE
    for (cl in num) {
      dd <- abs(o$table[[cl]] - n$table[[cl]]); dd[is.na(dd)] <- 0
      if (max(dd) > 1e-8) {
        hit <- TRUE; k <- which.max(dd)
        if (is.null(coldiff[[cl]])) coldiff[[cl]] <- list(n = 0, max = 0, ex = NULL)
        coldiff[[cl]]$n <- coldiff[[cl]]$n + 1
        if (max(dd) > coldiff[[cl]]$max) {
          coldiff[[cl]]$max <- max(dd)
          coldiff[[cl]]$ex <- sprintf("%s band %d: reference %.2f, new %.2f (input threshold %s)", nm, k,
            o$table[[cl]][k], n$table[[cl]][k],
            if (!is.null(cases[[nm]]$threshold) && is.null(cases[[nm]]$freq)) format(cases[[nm]]$threshold[k]) else "interp.")
        }
      }
    }
    if (hit) ndiff <- ndiff + 1
  }
  cat(sprintf("  cases: %d | SII differs in %d (max |d SII| %.2e) | band table differs in %d\n",
              length(cases), nsii, max_dsii, ndiff))
  if (length(coldiff)) for (cl in names(coldiff))
    cat(sprintf("  column %-6s differs in %3d cases, max %.2f; e.g. %s\n", cl, coldiff[[cl]]$n,
                coldiff[[cl]]$max, coldiff[[cl]]$ex))
  else cat("  RESULT: identical to the reference for every case\n")
  cols_new <- setdiff(names(new[["AnnexC1"]]$table), names(old[["AnnexC1"]]$table))
  cols_old <- setdiff(names(old[["AnnexC1"]]$table), names(new[["AnnexC1"]]$table))
  if (length(cols_new)) cat("  columns only in this version:", paste(cols_new, collapse = ", "), "\n")
  if (length(cols_old)) cat("  columns only in the reference:", paste(cols_old, collapse = ", "), "\n")
  if (length(errs)) { cat("  ERROR MISMATCHES:\n"); cat(paste0("    ", errs, "\n"), sep = "") }
}
cat("\nPaste everything from 'Versions in the CRAN archive' down to Claude.\n")
