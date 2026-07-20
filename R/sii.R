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
                coupling="custom_occluded"
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
  ##   frequency (as required by ANSI S3.5-1997 section 4.2)
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
  data(list=data.name, package="SII", envir=environment())
  table <- get(data.name)

  ## Get the correct importance functions
  if(missing(importance) || is.character(importance) )
    {
      importance=match.arg(importance)  
      if(importance!="SII")
        {
          sic.name <- paste("sic.",data.name, sep="")
          data(list=sic.name, package="SII", envir=environment())
          sic.table <- get(sic.name)
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
    overall_spl <- 10 * log10(sum(10^(speech/10), na.rm = TRUE))
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
  ## Calculate Prescription Gain if requested
  #########
  mpo <- NULL
  if (!is.null(prescription) && prescription == "NAL-R") {
    gain <- calculate_nalr_gain(freq, threshold)
  } else if (!is.null(prescription) && prescription == "Open-NL") {
    # Calculate dynamic WDRC gain independently for each frequency band
    # This acts as a multi-channel compressor, preventing upward spread of masking
    gain <- calculate_open_nl_gain(freq, threshold, speech, gender, experience, config, age, coupling)
    
    # Apply NAL-SSPL90 MPO (Maximum Power Output) Limiting
    # Instead of hard peak clipping, we use a high compression ratio (10:1) 
    # for the portion of the signal that exceeds the maximum output limit.
    mpo <- calculate_nal_sspl90(threshold, gain, ldl)
    raw_output <- speech + gain
    overshoot <- pmax(0, raw_output - mpo)
    
    final_output <- pmin(raw_output, mpo) + (overshoot / 10.0)
    gain <- final_output - speech
    
    # Ensure no negative gain after MPO restriction
    gain <- pmax(gain, 0)
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
  ## Calcuate SII following ANSI S3.5-1997 Section 4
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
  ## Formula A1, which extends formula 11 to handle conductive
  ## hearing loss (Ji)
  sii.tab$"Li" <- 1 - (sii.tab$"E'i" - sii.tab$"Ui" - 10 - sii.tab$"Ji" )/160 
  sii.tab$"Li" <- enforce.range(sii.tab$"Li")
  
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
    # k' = [ (k/30)^p + m^p ]^(1/p) where k/30 is equivalent to our bounded Ki
    sii.tab$"Ki" <- (sii.tab$"Ki"^p + m^p)^(1/p)
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
#' \deqn{Sones_{Total} = \sum Sones_i}
#' 
#' @param x An object of class \code{SII}.
#' @return A numeric value representing the total loudness in Sones.
#' @export
calculate_loudness <- function(x) {
  if (!inherits(x, "SII")) {
    stop("Input must be an object of class 'SII'")
  }
  
  # Aided Equivalent Speech Spectrum Level (E'i) and Threshold (T'i)
  E_prime <- x$table[, "E'i"]
  T_prime <- x$table[, "T'i"]
  
  # Predict Uncomfortable Loudness Level (UCL) for each band
  # Normal UCL is ~100 dB SPL. It increases slightly with hearing loss.
  UCL <- 100 + 0.25 * pmax(0, T_prime - 20, na.rm = TRUE)
  
  # Patient's Dynamic Range (Threshold to UCL)
  DR <- pmax(1, UCL - T_prime, na.rm = TRUE) # pmax(1) prevents division by zero
  
  # Sensation Level (dB above threshold)
  # Speech peaks are 15 dB above the RMS E'i spectrum level
  peak_level <- E_prime + 15
  SL <- pmax(0, peak_level - T_prime, na.rm = TRUE)
  
  # Normalize to a 100-Phon scale to model recruitment
  # E.g., if SL equals the full Dynamic Range, perceived loudness is 100 Phons
  phons <- (SL / DR) * 100 
  
  # Stevens' Power Law (1 Sone = 40 Phons. Sones double every 10 Phons)
  sones_band <- ifelse(phons >= 40,
                       2^((phons - 40) / 10),
                       (phons / 40)^2.5)
                       
  # Sum specific loudness across all critical bands to get Total Loudness (Sones)
  total_sones <- sum(sones_band, na.rm = TRUE)
  
  return(total_sones)
}
