# utils::globalVariables(c("critical", "octave", "onethird", "equal", 
#                          "sic.critical", "sic.octave", "sic.onethird", "sic.equal"))

sii <- function(
                speech=c("normal","raised","loud","shout"),
                noise,
                threshold,
                loss,
                freq,
                method=c(
                  "critical",
                  "equal-contributing",
                  "one-third octave",
                  "octave"
                  ),
                importance=c(
                  "SII",
                  "NNS",
                  "CID22",
                  "NU6",
                  "DRT",
                  "ShortPassage",
                  "SPIN",
                  "CST"
                  ),
                interpolate=FALSE,
                prescription=NULL,
                desensitization=FALSE,
                ldl=NULL,
                gender="male",
                experience="experienced",
                config="bilateral",
                age="adult",
                age_years=NULL,
                age_months=NULL,
                coupling="custom_occluded",
                module="standard",
                transducer="inserts",
                custom_gain=NULL,
                measured_wrs=NULL,
                wrs_level=NULL,
                distortion_category=NULL,
                ten_edge_hf=NULL,
                ten_edge_lf=NULL,
                nal_ldf=FALSE
                )
{
  ## Assumptions:
  ##
  ## freq: If provided, frequencies in Hz at which speech, noise, and/or
  ##    threshold values are measured.  If missing, frequencies will
  ##    corresponding to those utilized by the specified method.
  ##    Note that, frequencies must be provided if "interpolate=TRUE"
  ##
  ## speech: Speech level in dB at each frequency, or one of levels of
  ##    stated vocal effort ("raised",  "normal",  "loud", "shout")
  ##    provided by the standard, in which case the reference levels
  ##    in dB will be applied.
  ##
  ## noise: Noise dB at each frequency, defaults to -50 dB at each
  ##   frequency (as required by ANSI/ASA S3.5-1997 (R2024) section 4.2)
  ##
  ## threshold: Hearing threshold level in dB at each frequency. If
  ##   missing, assumed to be 0.
  ##
  ## loss: Hearing threshold loss factor due to the presence of
  ##   conductive hearing loss in dB.  If missing, assumed to be 0

  ## Determine which method will be used
  method=match.arg(method)

  ## Get the appropriate table of constants
  data.name <- switch(method,
                      "critical"="critical",
                      "one-third octave"="onethird",
                      "equal-contributing"="equal",
                      "octave"="octave"
                      )
  if (!exists(data.name, envir = .GlobalEnv)) {
    if (file.exists(file.path("data", paste0(data.name, ".rda")))) {
      load(file.path("data", paste0(data.name, ".rda")), envir=.GlobalEnv)
    } else {
      data(list=data.name, package="SII", envir=.GlobalEnv)
    }
  }
  table <- get(data.name, envir=.GlobalEnv)

  ## Get the correct importance functions
  if(missing(importance) || is.character(importance) )
    {
      importance=match.arg(importance)  
      if(importance!="SII")
        {
          sic.name <- paste("sic.",data.name, sep="")
          if (!exists(sic.name, envir = .GlobalEnv)) {
            if (file.exists(file.path("data", paste0(sic.name, ".rda")))) {
              load(file.path("data", paste0(sic.name, ".rda")), envir=.GlobalEnv)
            } else {
              data(list=sic.name, package="SII", envir=.GlobalEnv)
            }
          }
          sic.table <- get(sic.name, envir=.GlobalEnv)
          table[,"Ii"] <- sic.table[[importance]]
        }
    }
  else
    if(length(importance) != nrow(table))
      stop("`importance' vector must have length ", nrow(table), " for method `",method,"'.")
    else
      table[,"Ii"] <- importance

  
  ## Handle missing freq
  if(missing(freq))
    if(interpolate)
      stop("`freq' must be specified when `interpolate=TRUE'")
    else
      freq <- table$fi

  ## Get appropriate reference values for speech 
  if(is.character(speech))
    {
      const.speech=TRUE
      speech <- match.arg(speech)
      vocal_effort <- speech
      speech <- table[[speech]]
    }
  else {
    const.speech=FALSE
    # Calculate the overall broadband SPL for the custom speech array
    if ("hi" %in% names(table) && "li" %in% names(table) && length(speech) == length(table$hi)) {
      overall_spl <- 10 * log10(sum((10^(speech/10)) * (table$hi - table$li), na.rm = TRUE))
    } else {
      overall_spl <- 10 * log10(sum(10^(speech/10), na.rm = TRUE))
    }
    vocal_effort <- paste0(round(overall_spl), " dB SPL")
  }

  ## Handle missing noise
  if(missing(noise))
    noise <- rep(-50, length(freq))
  
  ## Handle missing threshold
  if(missing(threshold))
    threshold <- rep(0, length(freq))

  ## Handle missing loss
  if(missing(loss))
    loss <- rep(0, length(freq))

  ## Ensure that speech, noise, and threshold are the correct size
  nfreq <- length(freq)
  if(length(speech)    != nfreq && !const.speech)
    stop("`speech' must have the same length as `freq'.")
  if(
     length(noise)     != nfreq ||
     length(threshold) != nfreq ||
     length(loss)      != nfreq
     )
    stop("`noise', `threshold', and `loss` must have the same length as `freq'.")
  
  ## Check for missing values
  any.nas <- any(is.na(c(noise,threshold,loss,freq)) )
  if(!const.speech)
    any.nas <- any.nas || any(is.na(speech))
  if(any.nas && !interpolate)
        stop("Missing values only permitted when `interpolate=TRUE'")
  
  ## Sort values into frequency order
  ord <- order(freq)
  freq      <- freq     [ord]
  noise     <- noise    [ord]
  threshold <- threshold[ord]
  loss      <- loss     [ord]

  if(!const.speech)
    speech    <- speech   [ord]

  
  ## Store these values in the return object.
  retval <- list()
  retval$call <- match.call()
  retval$orig <- list( freq, speech, noise, threshold, loss )
  retval$experience <- experience
  retval$gender <- gender
  retval$config <- config
  retval$age <- age
  retval$age_years <- age_years
  retval$coupling <- coupling
  retval$module <- module
  retval$transducer <- transducer

  
  if(interpolate)
    {

      sii.freqs <- table[,"fi"]

      approx.l <- function(obs.freq,value,target.freq)
        {
          nas <- is.na(value)
          if(any(nas))
            {
              warning(sum(nas), " missing values ommitted")
              value    <- value[!nas]
              obs.freq <- obs.freq[!nas]
            }
          
          if(length(value) < 2)
            {
              if (length(value) == 1)
                return(rep(value, length(target.freq)))
              else
                return(rep(NA, length(target.freq)))
            }
            
          tmp <- approx(
                        x=log10(obs.freq),
                        y=value,
                        xout=log10(target.freq),
                        method="linear",  
                        rule=2
                        )
          tmp$y
        }
      #debug(approx.l)
      
      ## Interpolate unobserved frequencies
      noise     <- approx.l(freq, noise,     sii.freqs)
      threshold <- approx.l(freq, threshold, sii.freqs)
      loss      <- approx.l(freq, loss,      sii.freqs)

      if(!const.speech)
        speech  <- approx.l(freq, speech,    sii.freqs)
      
      freq   <- sii.freqs
    }
      
  #########
  ## Predict WRS and Determine Distortion Category (Margolis et al., 2025)
  #########
  predicted_wrs <- NULL
  
  if (!is.null(measured_wrs) && !is.null(wrs_level) && is.null(distortion_category)) {
    # Estimate speech spectrum at wrs_level
    if ("hi" %in% names(table) && "li" %in% names(table)) {
      overall_normal <- 10 * log10(sum((10^(table$normal / 10)) * (table$hi - table$li), na.rm = TRUE))
    } else {
      overall_normal <- 62.35
    }
    wrs_speech <- table$normal + (wrs_level - overall_normal)
    
    # Recursive call for unaided SII at wrs_level
    wrs_sii_obj <- sii(speech = wrs_speech, noise = rep(-50, length(freq)), threshold = threshold, loss = loss, freq = freq, method = method, importance = importance, interpolate = FALSE, desensitization = FALSE)
    
    # Predicted WRS using standard NU-6 transfer function (Studebaker)
    predicted_wrs <- 100 * (1 - 10^(-(wrs_sii_obj$sii * 3.28)))
    
    diff_pct <- measured_wrs - predicted_wrs
    
    # Margolis (2025) UM Ranges (Normal: > -2.7, Low: -2.8 to -13.5, Moderate: -13.6 to -24.3, High: < -24.3)
    if (diff_pct > -2.7) {
      distortion_category <- "Normal"
    } else if (diff_pct >= -13.5) {
      distortion_category <- "Low"
    } else if (diff_pct >= -24.3) {
      distortion_category <- "Moderate"
    } else {
      distortion_category <- "High"
    }
  }

  #########
  ## Calculate Prescription Gain if requested
  #########
  mpo <- NULL
  if (!is.null(custom_gain)) {
    # If custom gain is provided, ensure it matches the sii calculation frequencies by interpolation
    if (length(custom_gain) == length(freq)) {
      gain <- custom_gain
    } else if (length(custom_gain) == length(retval$orig[[1]])) {
      # Interpolate from original freq to interpolated freq
      nas <- is.na(custom_gain)
      if(any(nas)) {
        custom_gain <- custom_gain[!nas]
        orig_f <- retval$orig[[1]][!nas]
      } else {
        orig_f <- retval$orig[[1]]
      }
      gain <- approx(x=log10(orig_f), y=custom_gain, xout=log10(freq), method="linear", rule=2)$y
    } else {
      stop("custom_gain must match the length of the frequencies used in the method or the original frequencies.")
    }
    # For custom gain benchmarking, we bypass the MPO calculation to test the exact target gain limits
  } else if (!is.null(prescription) && inherits(prescription, "prescription_target")) {
    # If the user supplied a pre-calculated prescription_target S3 object
    
    # Interpolate gain to sii evaluation frequencies
    if (length(prescription$gain) == length(freq) && all(prescription$freq == freq)) {
       gain <- prescription$gain
       mpo <- prescription$mpo
    } else {
       gain <- approx(x = log10(prescription$freq), y = prescription$gain, xout = log10(freq), rule = 2)$y
       mpo <- approx(x = log10(prescription$freq), y = prescription$mpo, xout = log10(freq), rule = 2)$y
    }
    
    raw_output <- speech + gain
    overshoot <- pmax(0, raw_output - mpo)
    final_output <- pmin(raw_output, mpo) + (overshoot / 10.0)
    gain <- pmax(final_output - speech, 0)
  } else if (!is.null(prescription) && is.character(prescription) && prescription == "NAL-R") {
    gain <- calculate_nalr_gain(freq, threshold)
  } else if (!is.null(prescription) && is.character(prescription) && prescription == "Open-NL") {
    gain <- calculate_open_nl_gain(freq = freq, threshold = threshold, input_level = speech, gender = gender, experience = experience, config = config, age = age, coupling = coupling, module = module, ldl = ldl, age_years = age_years, age_months = age_months, loss = loss, distortion_category = distortion_category, ten_edge_hf = ten_edge_hf, ten_edge_lf = ten_edge_lf)
  } else {
    gain <- rep(0, length(speech))
  }
  
  ## Save the unaided speech to return it for plotting
  unaided_speech <- speech
  
  ## Apply gain to speech and external noise for aided calculation
  speech <- speech + gain
  # Only amplify external noise if explicitly provided, not the -50 internal default
  has_explicit_noise <- !is.null(match.call()$noise)
  if (has_explicit_noise) {
    noise <- noise + gain
  }

  #########
  ## Calcuate SII following ANSI/ASA S3.5-1997 (R2024) Section 4
  #########
  
  ## Setup: Create worksheet
  col.names <- c("Fi", "E'i", "N'i", "T'i", "Vi", "Bi", "Ci", "Zi",
                 "Xi", "X'i", "Di", "Ui", "Ji", "Li", "Ki", "Ai",
                 "Ii", "IiAi")  
  sii.tab <- matrix(nrow=length(freq),ncol=length(col.names))
  colnames(sii.tab) <- col.names
  rownames(sii.tab) <- 1:nrow(sii.tab)

  sii.tab <- as.data.frame(sii.tab)

  #####
  ## Step 1: Select calculation method
  #####

  ## The calculation method is already stored in 'method'

  ## Copy midband frequencies into the table
  sii.tab$"Fi" <- freq

  #####
  ## Step 2: Equivalent speech E'i, noise N'i, and hearing threshold
  ##         T'i spectra
  #####
  sii.tab$"E'i" <- speech
  sii.tab$"N'i" <- noise
  sii.tab$"T'i" <- threshold
  sii.tab$"Ji"  <- loss

  #####
  ## Step 3: Equivalent masking spectrum level (Zi)
  #####
  if(method=="octave")
    ## 4.3.1
    sii.tab$"Zi" <- sii.tab$"N'i"
  else 
    {
      ## 4.3.2.1 self-speech masking level
      sii.tab$"Vi" <- sii.tab$"E'i" - 24

      ## 4.3.2.2
      sii.tab$"Bi" <- pmax(sii.tab$"N'i", sii.tab$"Vi")

      ## 4.3.2.3 slope per octive of spread of masking, Ci
      if(method=="critical" ||
         method=="equal-contributing")
        {
          sii.tab$"Ci" <- -80 + 0.6*( sii.tab$"Bi" + 10*log10(table$"hi" - table$"li") )
        }
      else # method=="one-third octave"
        {
          sii.tab$"Ci" <- -80 + 0.6*( sii.tab$"Bi" + 10*log10(table$"fi") - 6.353 )          
        }

      if(method=="critical" ||
         method=="equal-contributing")
        {
          Zifun <- function(i) 
            {
              slow <- TRUE

              if(slow)
                {
                  accum <- 10 ^ (0.1 * sii.tab[i,"N'i"])
                  if(i>1)
                    for(k in 1:(i-1))
                      accum <- accum + 10 ^ (0.1 * (sii.tab[k,"Bi"] + 3.32*sii.tab[k,"Ci"] * log10( table[i,"fi"] / table[k,"hi"] ) ) )
                  retval <- 10 * log10(accum)
                }
              else
                {
                  if(i>1)
                    inner <- sum( 10 ^ (0.1 * ( sii.tab[1:(i-1),"Bi"] + 3.32*sii.tab[1:(i-1),"Ci"] * log10( table[i,"fi"] / table[1:(i-1),"hi"] ) ) ) )
                  else
                    inner <- 0
                  retval <- 10 * log10( 10 ^ (0.1 * sii.tab[i,"N'i"] ) + inner )
                }

              retval
            }
          
          sii.tab$"Zi" = sapply(1:nrow(sii.tab), Zifun)

        }
      else # method=="one-third octave"
        {

          
          Zifun <- function(i) 
            {
              slow <- FALSE
              
              if(slow)
                {
                  accum <- 10 ^ (0.1 * sii.tab[i,"N'i"])
                  if(i>1)
                    for(k in 1:(i-1))
                      accum <- accum + 10 ^ (0.1 * ( sii.tab[k,"Bi"] + 3.32*sii.tab[k,"Ci"] * log10( 0.89 * table[i,"fi"] / table[k,"fi"] ) )  )
                  retval <- 10 * log10(accum)
                }
              else
                {

                  if(i>1)
                    inner <- sum( 10 ^ (0.1 * ( sii.tab[1:(i-1),"Bi"] + 3.32*sii.tab[1:(i-1),"Ci"] * log10( 0.89 * table[i,"fi"] / table[1:(i-1),"fi"] ) ) ) )
                  else
                    inner <- 0
              
                  retval <- 10 * log10( 10 ^ (0.1 * sii.tab[i,"N'i"] ) + inner )
                }
            }
          sii.tab$"Zi" = sapply(1:nrow(sii.tab), Zifun)
        }

      ## 4.3.2.4
      sii.tab[1,"Zi"] <- sii.tab[1,"Bi"]

    }
  
  #####
  ## Step 4: Equivalent internal noise spectrum level, X'i
  #####
  ## Copy reference internal noise spectrum Xi
  sii.tab$"Xi" <- table$"Xi"
  
  ## Calculate  X'i
  sii.tab$"X'i" <- sii.tab$"Xi" + sii.tab$"T'i" 

  #####
  ## Step 5: Equivalent disturbance spectrum, Di
  #####
  sii.tab$"Di" <- pmax( sii.tab$"Zi", sii.tab$"X'i" )

  #####
  ## Step 6: Level distortion factor, Li
  #####
  
  ## Standard speech spectrum level at normal vocal level Ui
  sii.tab$"Ui" <- table$"normal"
  
  ##         Calculate speech level distortion factor Li
  enforce.range <- function(x) 
    {
      x[x < 0] <- 0  # min is 0
      x[x > 1] <- 1  # max is 1
      x
    }
  if (nal_ldf) {
    # NAL-NL2 modifies the LDF onset based on the degree of hearing loss
    # Impaired ears tolerate higher presentation levels without losing intelligibility.
    # We shift the penalty onset by 0.5 * threshold.
    sii.tab$"Li" <- 1 - (sii.tab$"E'i" - sii.tab$"Ui" - 10 - sii.tab$"Ji" - (0.5 * sii.tab$"T'i"))/160
    sii.tab$"Li" <- enforce.range(sii.tab$"Li")
  } else {
    sii.tab$"Li" <- 1 - (sii.tab$"E'i" - sii.tab$"Ui" - 10 - sii.tab$"Ji" )/160 
    sii.tab$"Li" <- enforce.range(sii.tab$"Li")
  }
  
  ## Step 7: Calculate Ki
  sii.tab$"Ki" <- (sii.tab$"E'i" - sii.tab$"Di" + 15)/30
  sii.tab$"Ki" <- enforce.range( sii.tab$"Ki" )
  
  if (desensitization) {
    # Apply Hearing Loss Desensitization (Johnson 2013 / Ching et al. 2011)
    T_hl <- sii.tab$"T'i"
    
    # Calculate m and p variables based on frequency-specific hearing loss (T)
    m <- 1 / (1 + exp(0.075 * (T_hl - 66)))
    p <- (T_hl / 8) - 15
    
    # Prevent division by exactly zero for mathematical safety
    p[p == 0] <- -1e-6
    
    # Apply desensitization to the audibility index (Ki)
    # Using a linear multiplier instead of a hard asymptotic cap allows the numerical 
    # optimizer (L-BFGS-B) to maintain a non-zero gradient while still penalizing dead regions.
    sii.tab$"Ki" <- sii.tab$"Ki" * m
    sii.tab$"Ki" <- enforce.range(sii.tab$"Ki")
  }
  
  ##         Calculate Ai
  sii.tab$"Ai" <- sii.tab$"Li" * sii.tab$"Ki"
  
  ## Step 8: Copy band importance function values
  sii.tab[,"Ii"] <- table[,"Ii"]
  
  ##         Calculate Ii * Ai
  sii.tab[,"IiAi"] <- table[,"Ii"] * sii.tab[,"Ai"]
  
  ##         Sum IiAi to determine SII
  sii.val <- sum(sii.tab[,"IiAi"])  
  
  if (!is.null(prescription)) {
     # Calculate the unaided SII for comparison using a recursive call
     orig_noise <- noise
     if (has_explicit_noise) orig_noise <- noise - gain
     
     unaided_obj <- sii(speech = unaided_speech, noise = orig_noise, threshold = threshold, 
                        loss = loss, freq = freq, method = method, importance = importance, 
                        interpolate = FALSE, desensitization = desensitization)
     retval$unaided_sii <- unaided_obj$sii
  }

  ## Package it all up to return to the user
  retval$speech    <- speech
  retval$unaided_speech <- unaided_speech
  retval$vocal_effort <- vocal_effort
  retval$noise     <- noise
  retval$threshold <- threshold
  retval$loss      <- loss
  retval$freq      <- freq
  retval$gain      <- gain
  retval$mpo       <- mpo
  retval$prescription <- prescription
  retval$method    <- method
  retval$table     <- sii.tab
  retval$sii       <- sii.val
  retval$desensitization <- desensitization
  retval$module    <- module
  retval$age       <- age
  retval$age_years <- age_years
  retval$measured_wrs <- measured_wrs
  retval$predicted_wrs <- predicted_wrs
  retval$distortion_category <- distortion_category
  
  class(retval) <- "SII"
  
  retval
}

#' Calculate Psychoacoustic Loudness (Sones)
#'
#' @description
#' Calculates the total perceived loudness in Sones based on the specific
#' speech spectrum and hearing thresholds of the patient.
#' 
#' @details
#' The current implementation uses a first-order heuristic model of recruitment 
#' based on Stevens' Power Law, mapped over an estimated dynamic range. While it
#' is computationally fast and demonstrates the restoration of loudness conceptually,
#' it is not a full psychoacoustic model (like Moore-Glasberg / CAM2Q), as it does
#' not calculate basilar membrane excitation patterns via RoEx filters.
#'
#' \strong{Mathematical Formula:}
#' 
#' 1. \strong{Uncomfortable Loudness Level (UCL)} is predicted from the threshold ($T_i$):
#' \deqn{UCL_i = 100 + 0.25 \times \max(0, T_i - 20)}
#'
#' 2. \strong{Dynamic Range (DR)}:
#' \deqn{DR_i = \max(1, UCL_i - T_i)}
#' 
#' 3. \strong{Sensation Level (SL)} of speech peaks (RMS + 15 dB):
#' \deqn{SL_i = \max(0, E_i + 15 - T_i)}
#' 
#' 4. \strong{Loudness Level (Phons)} modeling recruitment:
#' \deqn{Phons_i = \left( \frac{SL_i}{DR_i} \right) \times 100}
#' 
#' 5. \strong{Specific Loudness (Sones)} per band via Stevens' Power Law:
#' \deqn{Sones_i = 2^{\frac{Phons_i - 40}{10}} \quad \text{for } Phons_i \ge 40}
#' \deqn{Sones_i = \left(\frac{Phons_i}{40}\right)^{2.5} \quad \text{for } Phons_i < 40}
#' 
#' 6. \strong{Total Loudness (Sones)}:
#' \deqn{Sones_{Total} = \sum Sones_i \times \text{calibration\_factor}}
#' 
#' The calibration factor (0.25 for 21 critical bands) is scaled dynamically based on the number of frequency bands
#' used in the underlying SII method (e.g., 21 for critical, 6 for octave) to ensure
#' equivalent loudness summation across different resolutions.
#' 
#' @param x An object of class \code{SII}.
#' @return A numeric value representing the total loudness in Sones.
# Internal helper to calculate monaural specific loudness per critical band
get_specific_loudness <- function(x) {
  if (!inherits(x, "SII")) {
    stop("Input must be an object of class 'SII'")
  }
  
  # Aided Equivalent Speech Spectrum Level (E'i) and Threshold (T'i)
  E_prime <- x$table[, "E'i"]
  X_prime <- x$table[, "X'i"]
  
  return(list(E_prime = E_prime, X_prime = X_prime))
}

#' @export
calculate_loudness <- function(x, ohc_proportion = 0.65) {
  if (is.null(x$table$"E'i")) {
    return(NA) # Cannot compute loudness without aided equivalent spectrum level
  }
  
  freqs <- x$table$"Fi"
  
  # The Equivalent Speech Spectrum Level (E'i) is already in dB/Hz (spectrum density)
  aided_density <- x$table$"E'i"
  # Use the original audiogram thresholds and frequencies passed into sii()
  # instead of the equivalent spectrum threshold T'i.
  orig_freqs <- x$freq
  orig_threshold <- x$threshold
  
  # Approximate the audiogram frequencies required by the model
  hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  htl <- approx(x = log10(orig_freqs), y = orig_threshold, xout = log10(hl_freqs), rule=2)$y
  
  # Conductive component (Air-Bone Gap)
  orig_loss <- if (!is.null(x$loss)) x$loss else rep(0, length(orig_freqs))
  abg <- approx(x = log10(orig_freqs), y = orig_loss, xout = log10(hl_freqs), rule=2)$y
  
  # Sensorineural component dictates OHC/IHC damage and recruitment
  sn_htl <- pmax(htl - abg, 0)
  
  ohc_loss <- pmin(ohc_proportion * sn_htl, 57.6)
  ihc_loss <- pmax(sn_htl - ohc_loss, 0)
  
  # Create a dense 1 Hz spectrum from the band densities
  dense_f <- seq(20, 15000, by=1)
  dense_l <- rep(-100, length(dense_f)) # noise floor
  
  # Interpolate the density (rule=1 returns NA outside the range, which we handle below)
  dense_l <- approx(x = log10(freqs), y = aided_density, xout = log10(dense_f), rule=1)$y
  
  # Roll off below the first band to prevent artificial low-frequency loudness
  idx_low <- which(dense_f < freqs[1])
  if (length(idx_low) > 0) {
    octaves_below <- log2(freqs[1] / dense_f[idx_low])
    dense_l[idx_low] <- aided_density[1] - 24 * octaves_below
  }
  
  # Roll off above the last band to prevent artificial high-frequency loudness
  last_freq <- freqs[length(freqs)]
  idx_high <- which(dense_f > last_freq)
  if (length(idx_high) > 0) {
    octaves_above <- log2(dense_f[idx_high] / last_freq)
    dense_l[idx_high] <- aided_density[length(aided_density)] - 24 * octaves_above
  }
  
  # Replace any remaining NAs with noise floor
  dense_l[is.na(dense_l)] <- -100
  
  # Conductive loss physically attenuates the signal in the middle ear before it reaches the cochlea.
  # We must subtract the ABG from the eardrum spectrum (dense_l) so the cochlea receives the correct energy.
  dense_abg <- approx(x = log10(orig_freqs), y = orig_loss, xout = log10(dense_f), rule=2)$y
  dense_l <- dense_l - dense_abg
  
  res <- calculate_loudness_chen2011(
    inputF = dense_f, 
    inputLdB = dense_l,
    HLcf = hl_freqs, 
    HLohcdB0 = ohc_loss, 
    HLihcdB0 = ihc_loss, 
    outerearcorrection='FreeField'
  )
  
  # Return both total loudness (Ldn) and specific loudness array (N_prime)
  return(list(total = res$Ldn, specific = res$N_prime, freq = res$CF))
}

#' Calculate Psychoacoustic Binaural Loudness (Sones)
#'
#' @description
#' Calculates the total perceived binaural loudness based on the Pieper et al. (2021) 
#' and Moore et al. (2016) binaural summation models.
#' 
#' @param x_left An object of class `SII` for the left ear.
#' @param x_right Optional. An object of class `SII` for the right ear. If NULL, assumes a perfectly symmetric bilateral fitting (`x_left == x_right`).
#' @param alpha_b Numeric. The binaural inhibition factor. Default is -0.25, reflecting classical normal-hearing binaural inhibition.
#' @return A numeric value representing the total binaural loudness in Sones.
#' @export
calculate_binaural_loudness <- function(x_left, x_right = NULL, alpha_b = -0.25) {
  l_left_res <- calculate_loudness(x_left)
  l_left <- if (is.list(l_left_res)) l_left_res$total else l_left_res
  
  if (is.null(x_right)) {
    l_right <- l_left
  } else {
    l_right_res <- calculate_loudness(x_right)
    l_right <- if (is.list(l_right_res)) l_right_res$total else l_right_res
  }
  
  # Pieper et al. (2021) / Moore et al. (2016) binaural inhibition heuristic
  l_bin <- l_left + l_right + alpha_b * sqrt(l_left * l_right)
  return(max(0, l_bin))
}
#' Export prescribed insertion gains for 50, 65, and 80 dB SPL input levels
#'
#' @param x An object of class `SII`
#' @return A data.frame containing frequency and the prescribed insertion gains
#' @export
export_gains <- function(x) {
  if (is.null(x$prescription)) {
    return(data.frame(Frequency = x$freq, Gain_50 = NA, Gain_65 = NA, Gain_80 = NA))
  }
  
  n_bands <- length(x$freq)
  method_name <- if (n_bands == 21) "critical" else 
                 if (n_bands == 18) "one-third octave" else 
                 if (n_bands == 17) "equal-contributing" else "octave"
  data_name <- if (n_bands == 21) "critical" else 
               if (n_bands == 18) "onethird" else 
               if (n_bands == 17) "equal" else "octave"
  
  local_env <- new.env()
  if (file.exists(file.path("data", paste0(data_name, ".rda")))) {
    load(file.path("data", paste0(data_name, ".rda")), envir=local_env)
  } else {
    data(list = data_name, package = "SII", envir = local_env)
  }
  tbl <- get(data_name, envir = local_env)
  
  if ("hi" %in% names(tbl) && "li" %in% names(tbl)) {
    overall_normal <- 10 * log10(sum((10^(tbl$normal / 10)) * (tbl$hi - tbl$li), na.rm = TRUE))
  } else {
    overall_normal <- 62.35
  }
  
  desens <- if (!is.null(x$desensitization)) x$desensitization else FALSE
  unaided_noise <- x$noise - x$gain
  
  res50 <- sii(speech = tbl$normal + (50 - overall_normal), noise = unaided_noise, threshold = x$threshold, loss = x$loss, freq = tbl$fi, method = method_name, prescription = x$prescription, desensitization = desens, experience = x$experience, gender = x$gender, config = x$config, age = x$age, age_years = x$age_years, age_months = x$age_months, coupling = x$coupling, module = x$module, distortion_category = x$distortion_category)
  res65 <- sii(speech = tbl$normal + (65 - overall_normal), noise = unaided_noise, threshold = x$threshold, loss = x$loss, freq = tbl$fi, method = method_name, prescription = x$prescription, desensitization = desens, experience = x$experience, gender = x$gender, config = x$config, age = x$age, age_years = x$age_years, age_months = x$age_months, coupling = x$coupling, module = x$module, distortion_category = x$distortion_category)
  res80 <- sii(speech = tbl$normal + (80 - overall_normal), noise = unaided_noise, threshold = x$threshold, loss = x$loss, freq = tbl$fi, method = method_name, prescription = x$prescription, desensitization = desens, experience = x$experience, gender = x$gender, config = x$config, age = x$age, age_years = x$age_years, age_months = x$age_months, coupling = x$coupling, module = x$module, distortion_category = x$distortion_category)
  
  data.frame(
    Frequency = x$freq,
    Gain_50 = round(res50$gain, 2),
    Gain_65 = round(res65$gain, 2),
    Gain_80 = round(res80$gain, 2),
    MPO = round(res65$mpo, 2)
  )
}
