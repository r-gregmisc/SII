source("R/benchmark_targets.R")
source("R/sii.R")
source("R/nalr.R")
source("R/moore_glasberg.R")

cat("========================================================\n")
cat(" MOORE & GLASBERG (2004) PHYSICS VALIDATION SUITE \n")
cat("========================================================\n\n")

# Helper to simulate a pure tone
simulate_tone <- function(freq_hz, spl_db, htl=0, abg=0) {
  # Create a dense spectrum from 20 to 20000 Hz
  f_dense <- seq(20, 20000, by=1)
  l_dense <- rep(-100, length(f_dense))
  
  # Inject pure tone energy
  idx <- which.min(abs(f_dense - freq_hz))
  l_dense[idx] <- spl_db
  
  # Calculate physical attenuation (Conductive block)
  l_dense <- l_dense - abg
  
  # Calculate anatomical damage (Sensorineural)
  sn_htl <- max(0, htl - abg)
  ohc <- min(0.9 * sn_htl, 57.6)
  ihc <- max(sn_htl - ohc, 0)
  
  # Evaluate loudness
  res <- calculate_loudness_chen2011(
    inputF = f_dense, 
    inputLdB = l_dense,
    HLcf = c(20, 20000), 
    HLohcdB0 = c(ohc, ohc), 
    HLihcdB0 = c(ihc, ihc), 
    outerearcorrection='FreeField'
  )
  return(res$Ldn)
}

cat("--- TEST 1: ANSI S3.4 / ISO 226 STANDARD ANCHOR ---\n")
cat("Expectation: A 1,000 Hz tone at 40 dB SPL must equal exactly 1.0 sones (40 phons).\n")
val1 <- simulate_tone(1000, 40)
cat(sprintf("Result: %.2f Sones\n\n", val1))

cat("--- TEST 2: LOUDNESS DOUBLING (STEVENS' POWER LAW) ---\n")
cat("Expectation: Loudness should roughly double every 10 dB increase.\n")
cat(sprintf(" 40 dB SPL: %.2f Sones\n", val1))
cat(sprintf(" 50 dB SPL: %.2f Sones\n", simulate_tone(1000, 50)))
cat(sprintf(" 60 dB SPL: %.2f Sones\n", simulate_tone(1000, 60)))
cat(sprintf(" 70 dB SPL: %.2f Sones\n", simulate_tone(1000, 70)))
cat(sprintf(" 80 dB SPL: %.2f Sones\n\n", simulate_tone(1000, 80)))

cat("--- TEST 3: COMPLETE SENSORINEURAL RECRUITMENT ---\n")
cat("Expectation: At 100 dB SPL, a severely impaired ear (60 dB HL) should perfectly match the loudness of a normal ear (0 dB HL).\n")
val_norm <- simulate_tone(1000, 100, htl=0, abg=0)
val_imp <- simulate_tone(1000, 100, htl=60, abg=0)
cat(sprintf(" Normal Ear (0 dB HL) @ 100 dB SPL: %.2f Sones\n", val_norm))
cat(sprintf(" Impaired Ear (60 dB HL) @ 100 dB SPL: %.2f Sones\n\n", val_imp))

cat("--- TEST 4: BROADBAND LOUDNESS SUMMATION ---\n")
cat("Expectation: 65 dB SPL of broadband speech should be significantly louder than a 65 dB SPL pure tone due to critical band summation.\n")
val_pure <- simulate_tone(1000, 65)

# Simulate 65 dB SPL broadband speech using the SII engine
f_speech <- c(250, 500, 1000, 2000, 4000, 8000)
res_speech <- sii(speech = "normal", threshold = rep(0, 6), loss = rep(0, 6), freq = f_speech, method = "octave", custom_gain = rep(0, 6))
val_broad <- calculate_loudness(res_speech)

cat(sprintf(" 65 dB SPL Pure Tone: %.2f Sones\n", val_pure))
cat(sprintf(" 65 dB SPL Broadband Speech: %.2f Sones\n\n", val_broad))

cat("--- TEST 5: SITE-OF-LESION (CONDUCTIVE VS SENSORINEURAL) ---\n")
cat("Expectation: A 90 dB SPL signal into a 50 dB Conductive loss yields the loudness of a 40 dB SPL signal in a normal ear (1 sone). A 90 dB SPL signal into a 50 dB Sensorineural loss yields much higher loudness due to recruitment.\n")
val_cond <- simulate_tone(1000, 90, htl=50, abg=50)
val_sens <- simulate_tone(1000, 90, htl=50, abg=0)
cat(sprintf(" 50 dB Conductive Loss @ 90 dB SPL: %.2f Sones\n", val_cond))
cat(sprintf(" 50 dB Sensorineural Loss @ 90 dB SPL: %.2f Sones\n\n", val_sens))

cat("========================================================\n")
cat(" VALIDATION COMPLETE \n")
cat("========================================================\n")
