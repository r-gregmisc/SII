import re

with open("R/moore_glasberg.R", "r") as f:
    text = f.read()

bad_text = "  Ldn <- sum(E) * cambin * 1.525e-8\n"

good_text = """  # ---- Specific Loudness Computation (Moore, Glasberg & Baer, 1997) ----
  # Convert cochlear excitation to specific loudness.
  # Normal hearing uses a highly compressive exponent (alpha = 0.2).
  # Impaired hearing (OHC loss) loses compression, so alpha approaches 1.0 (linear).
  # Critically, as alpha increases, the scaling constant C MUST decrease so that 
  # loudness recruitment is complete (impaired = normal) at 100 dB SPL (E = 1e10).
  
  # Normal parameters
  G_norm <- 10^( (CF / (0.0191*CF + 1.1)) / 10 ) # Normal active gain
  A_norm <- G_norm * 1.5 # Internal noise excitation
  
  # Impaired parameters
  A <- A_norm
  
  # Calculate alpha: 0.2 for normal, approaches 1.0 for OHC loss
  g_norm_dB <- CF / (0.0191*CF + 1.1)
  g_imp_dB <- pmax(g_norm_dB - HLohcdB, 0.1)
  alpha <- pmin(1.0, 0.2 * (g_norm_dB / g_imp_dB))
  
  # Calculate the actual impaired excitation at 100 dB SPL (E_100_imp)
  # A 100 dB SPL signal is attenuated by the IHC loss function
  EdB_100 <- rep(100, length(CF))
  EdB_100_imp <- EdB_100 - HLihcdB * (1 - 0.5/(1+exp(-0.2*((EdB_100-52)-(HLihcdB+20)))))
  E_100_imp <- 10^(EdB_100_imp/10)
  
  # Normal loudness at 100 dB SPL
  E_100_norm <- 1e10
  N_norm_100 <- 0.046871 * ( (E_100_norm + A_norm)^0.2 - A_norm^0.2 )
  
  # C_imp anchors the impaired specific loudness to equal normal loudness at 100 dB SPL
  C_imp <- N_norm_100 / ( (E_100_imp + A)^alpha - A^alpha )
  
  # Specific loudness (sones/ERB)
  # Below 100 dB SPL, use the impaired recruitment function
  N_prime_imp <- C_imp * ( (E + A)^alpha - A^alpha )
  
  # Above 100 dB SPL, recruitment is complete, so loudness reverts to the normal ear's compressive function
  # We must use the theoretical UNATTENUATED normal energy for SPLs > 100 dB to match normal loudness correctly.
  E_unattenuated <- 10^( (EdB + HLihcdB * (1 - 0.5/(1+exp(-0.2*((EdB-52)-(HLihcdB+20)))))) / 10 )
  N_prime_norm <- 0.046871 * ( (E_unattenuated + A_norm)^0.2 - A_norm^0.2 )
  
  # Crossover at the impaired 100 dB SPL threshold
  N_prime <- ifelse(E > E_100_imp, N_prime_norm, N_prime_imp)
  # Prevent any mathematical underflows yielding negative loudness
  N_prime <- pmax(0, N_prime)
  
  # Total loudness is the integral across the ERB scale
  Ldn <- sum(N_prime) * cambin\n"""

text = text.replace(bad_text, good_text)

with open("R/moore_glasberg.R", "w") as f:
    f.write(text)
