plot.SII <- function(x, clinical = FALSE, legend = TRUE, legend_only = FALSE, ...)
  {
    if (clinical) {
      freq <- x$freq
      
      # Determine calculation method to fetch bandwidths for spectrum-to-band conversion
      n_bands <- length(freq)
      method_name <- if (n_bands == 21) "critical" else 
                     if (n_bands == 18) "one-third octave" else 
                     if (n_bands == 17) "equal-contributing" else "octave"
      data_name <- if (n_bands == 21) "critical" else 
                   if (n_bands == 18) "onethird" else 
                   if (n_bands == 17) "equal" else "octave"
                  
      local_env <- new.env()
      if (file.exists(file.path("data", paste0(data_name, ".rda")))) {
        load(file.path("data", paste0(data_name, ".rda")), envir = local_env)
      } else {
        data(list = data_name, package = "SII", envir = local_env)
      }
      tbl <- get(data_name, envir = local_env)
      
      # Calculate the Bandwidth Correction factor in dB
      if (!is.null(tbl$Deltai)) {
        bw_db <- tbl$Deltai
      } else {
        bw_db <- 10 * log10(tbl$hi - tbl$li)
      }
      
      # Convert all ANSI Spectrum Levels (dB SPL/Hz) to Clinical Band Levels (dB SPL)
      speech <- x$table[, "E'i"] + bw_db
      noise <- x$table[, "N'i"] + bw_db
      f_oct <- c(250, 500, 1000, 2000, 4000, 8000)
      
      if (!is.null(x$transducer) && x$transducer == "supra_aural") {
        # Supra-Aural Headphones (TDH-39) use REDD to directly convert HL to Real-Ear SPL
        # We bypass RETSPL and RECD entirely.
        # Standard Adult REDD (Scollie et al., 1998)
        redd <- c(14.0, 14.0, 10.0, 17.0, 16.0, 19.0)
        eardrum_offset <- approx(x = log10(f_oct), y = redd, xout = log10(freq), rule = 2)$y
      } else {
        # Insert Earphones (ER-3A) use RETSPL + RECD
        retspl <- c(14.0, 5.5, 0.0, 3.0, 5.5, 0.0)
        
        # DSL v5.0a RECD (Real-Ear-to-Coupler Difference) based on specific age bracket
        if (is.null(x$age) || x$age == "adult") {
          recd <- c(2.0, 4.0, 5.0, 6.0, 8.0, 4.0)
        } else if (x$age == "child_36_59") {
          recd <- c(3.0, 6.0, 8.0, 12.0, 15.0, 14.0)
        } else if (x$age == "child_24_35") {
          recd <- c(3.0, 6.0, 9.0, 13.0, 15.0, 15.0)
        } else if (x$age == "child_12_23") {
          recd <- c(4.0, 6.0, 9.0, 14.0, 17.0, 16.0)
        } else if (x$age == "child_6_11") {
          recd <- c(4.0, 7.0, 10.0, 15.0, 18.0, 18.0)
        } else if (x$age == "child_0_5") {
          recd <- c(4.0, 7.0, 11.0, 16.0, 21.0, 21.0)
        } else {
          # Fallback generic pediatric
          recd <- c(4.0, 6.0, 8.0, 10.0, 12.0, 9.0)
        }
        
        # Interpolate RETSPL + RECD to get the True Eardrum SPL offset
        eardrum_offset <- approx(x = log10(f_oct), y = retspl + recd, xout = log10(freq), rule = 2)$y
      }
      
      # True Clinical SPLogram Eardrum Threshold
      thresh_spl <- x$table[, "T'i"] + eardrum_offset
      
      # The masking threshold is the maximum of the internal/external noise and hearing threshold in SPL
      masker <- pmax(noise, thresh_spl, na.rm=TRUE)
      
      # Increase margins for legend but keep clipping enabled (xpd=FALSE) for the main plot
      old_par <- par(no.readonly = TRUE)
      on.exit(par(old_par))
      par(mar = c(10, 4, 4, 2) + 0.1, xpd = FALSE)
      
      # Determine bounds for the plot
      y_min <- 0 # Start Y axis at 0 dB SPL
      y_max <- max(c(100, thresh_spl, noise, speech, x$mpo), na.rm=TRUE) + 5
      
      is_aided <- !is.null(x$prescription)
      
      if (grepl("dB SPL", x$vocal_effort)) {
        vocal_effort_str <- paste("Input Level:", x$vocal_effort)
      } else {
        vocal_effort_str <- paste("Vocal Effort:", tools::toTitleCase(x$vocal_effort))
      }
      
      line1 <- if (is_aided) paste("Clinical SPLogram - Aided SII:", round(x$sii, 3), " (Unaided:", round(x$unaided_sii, 3), ")") else paste("Clinical SPLogram - SII:", round(x$sii, 3))
      line2 <- vocal_effort_str
      
      plot_title <- paste(line1, "\n", line2, sep="")
      
      has_noise <- !is.null(x$call$noise)
      
      # Prepare Legend Variables
      leg_names <- c("Speech Level (E'i)", "Hearing Threshold (T'i)")
      if (is_aided) {
         presc_label <- if (!is.null(x$prescription_name)) x$prescription_name else "Aided"
         leg_names[1] <- paste("Aided Speech Level (", presc_label, ")", sep="")
      }
      leg_cols <- c("forestgreen", "red")
      leg_pch <- c(NA, 4)
      leg_lty <- c(1, 1)
      leg_lwd <- c(2, 2)
      leg_cex <- c(1, 1.2)
      
      if (is_aided) {
        leg_names <- c(leg_names, "Unaided Speech Level")
        leg_cols <- c(leg_cols, "forestgreen")
        leg_pch <- c(leg_pch, NA)
        leg_lty <- c(leg_lty, 2)
        leg_lwd <- c(leg_lwd, 2)
        leg_cex <- c(leg_cex, 1)
      }
      
      if (has_noise) {
        leg_names <- c(leg_names, "Noise Level (N'i)")
        leg_cols <- c(leg_cols, "darkgray")
        leg_pch <- c(leg_pch, NA)
        leg_lty <- c(leg_lty, 2)
        leg_lwd <- c(leg_lwd, 2)
        leg_cex <- c(leg_cex, 1)
      }
      
      if (!is.null(x$mpo)) {
        leg_names <- c(leg_names, "MPO / SSPL90")
        leg_cols <- c(leg_cols, "black")
        leg_pch <- c(leg_pch, 8)
        leg_lty <- c(leg_lty, 2)
        leg_lwd <- c(leg_lwd, 2)
        leg_cex <- c(leg_cex, 1.2)
      }
      
      leg_names <- c(leg_names, if (is_aided) "Aided Dynamic Range" else "Speech Dynamic Range")
      leg_cols <- c(leg_cols, grDevices::rgb(0.2, 0.8, 0.2, 0.3))
      leg_pch <- c(leg_pch, 15)
      leg_lty <- c(leg_lty, NA)
      leg_lwd <- c(leg_lwd, NA)
      leg_cex <- c(leg_cex, 2)
      
      if (is_aided) {
        leg_names <- c(leg_names, "Unaided Dynamic Range")
        leg_cols <- c(leg_cols, grDevices::rgb(0.5, 0.5, 0.5, 0.2))
        leg_pch <- c(leg_pch, 15)
        leg_lty <- c(leg_lty, NA)
        leg_lwd <- c(leg_lwd, NA)
        leg_cex <- c(leg_cex, 2)
      }
      
      # If legend_only is true, draw the isolated legend and return immediately
      if (legend_only) {
        plot(1, type="n", axes=FALSE, xlab="", ylab="", main="")
        legend("center",
               legend = leg_names,
               col = leg_cols,
               pch = leg_pch,
               lty = leg_lty,
               lwd = leg_lwd,
               pt.cex = leg_cex,
               bg = "white",
               cex = 1.2,
               bty = "n"
          )
        return(invisible())
      }
      
      plot(
           x = freq, 
           y = thresh_spl, 
           type = "n", # Draw empty plot first
           log = "x",
           xlab = "Frequency (Hz)", 
           ylab = "Level (dB SPL)",
           ylim = c(y_min, y_max), 
           xlim = c(250, 8000),
           xaxt = "n", # Suppress default x-axis to draw custom octave intervals
           main = plot_title,
           ...
           ) 
      
      # Draw custom octave x-axis
      axis(1, at = c(250, 500, 1000, 2000, 4000, 8000), labels = c(250, 500, 1000, 2000, 4000, 8000))
      
      # Shade the Unaided Speech Dynamic Range (+12 / -18 dB)
      if (is_aided) {
        u_top <- x$unaided_speech + bw_db + 12
        u_bottom <- x$unaided_speech + bw_db - 18
        u_valid <- !is.na(u_top) & !is.na(u_bottom) & !is.na(freq)
        if (any(u_valid)) {
          graphics::polygon(
            x = c(freq[u_valid], rev(freq[u_valid])),
            y = c(u_top[u_valid], rev(u_bottom[u_valid])),
            col = grDevices::rgb(0.5, 0.5, 0.5, 0.2),
            border = NA
          )
        }
      }
      
      # Shade the Aided (or standard if unaided) Speech Dynamic Range (+12 / -18 dB)
      a_top <- speech + 12
      a_bottom <- speech - 18
      a_valid <- !is.na(a_top) & !is.na(a_bottom) & !is.na(freq)
      if (any(a_valid)) {
          graphics::polygon(
            x = c(freq[a_valid], rev(freq[a_valid])),
            y = c(a_top[a_valid], rev(a_bottom[a_valid])),
            col = grDevices::rgb(0.2, 0.8, 0.2, 0.3),
            border = NA
          )
      }
      
      # Add vertical dashed lines for octave bands
      octaves <- c(250, 500, 1000, 2000, 4000, 8000)
      abline(v = octaves, lty = 3, col = "lightgray")
      
      # Draw lines
      lines(x = freq, y = thresh_spl, col = "red", lwd = 2, type = "l")
      
      # Draw exactly 6 threshold markers on the standard clinical octaves
      
      # Interpolate thresholds (in dB SPL) onto the exact octave grid
      octave_thresh_spl <- approx(x = log10(freq), y = thresh_spl, xout = log10(octaves), rule = 2)$y
      points(x = octaves, y = octave_thresh_spl, col = "red", pch = 4, lwd = 2, cex = 1.2)
      
      if (is_aided) {
        lines(x = freq, y = x$unaided_speech + bw_db, col = "forestgreen", lwd = 2, type = "l", lty = 2)
      }
      lines(x = freq, y = speech, col = "forestgreen", lwd = 2, type = "l")
      
      if (has_noise) {
        lines(x = freq, y = noise, col = "darkgray", lwd = 2, type = "l", lty = 2)
      }
      
      if (!is.null(x$mpo)) {
        lines(x = freq, y = x$mpo, col = "black", lwd = 2, type = "b", pch = 8, lty = 2)
        
        # MPO Collision Detector
        collision_idx <- which(speech >= x$mpo - 1)
        if (length(collision_idx) > 0) {
          points(x = freq[collision_idx], y = speech[collision_idx], col = "red", cex = 2.5, lwd = 3)
          text(x = 1000, y = y_max - 2, "WARNING: MPO COMPRESSION LIMITING DETECTED", col = "red", font = 2, cex = 1.2)
        }
      }
      
      if (legend) {
        par(xpd = TRUE) # Allow legend to be drawn outside the plot box
        legend("bottom",
               inset = c(0, -0.35),
               legend = leg_names,
               col = leg_cols,
               pch = leg_pch,
               lty = leg_lty,
               lwd = leg_lwd,
               pt.cex = leg_cex,
               bg = grDevices::rgb(1, 1, 1, 0.85), # Semi-transparent white background
               cex = 0.9,
               horiz = FALSE,
               ncol = 2, # Split into 2 columns to save vertical space
               bty = "n"
          )
      }
      
    } else {
      # If clinical=FALSE and the object is aided, show the 3-line Insertion Gain Plot
      if (!is.null(x$prescription)) {
        
        # Determine which calculation method was used to fetch the correct standard spectra
        n_bands <- length(x$freq)
        method_name <- if (n_bands == 21) "critical" else 
                       if (n_bands == 18) "one-third octave" else 
                       if (n_bands == 17) "equal-contributing" else "octave"
        data_name <- if (n_bands == 21) "critical" else 
                     if (n_bands == 18) "onethird" else 
                     if (n_bands == 17) "equal" else "octave"
        
        # Create a local environment to load the data to avoid cluttering the workspace
        local_env <- new.env()
        if (file.exists(file.path("data", paste0(data_name, ".rda")))) {
          load(file.path("data", paste0(data_name, ".rda")), envir = local_env)
        } else {
          data(list = data_name, package = "SII", envir = local_env)
        }
        tbl <- get(data_name, envir = local_env)
        
        # Calculate overall dB SPL levels of the standard Normal spectrum
        # Calculate overall normal speech SPL properly by integrating over bandwidth (ANSI S3.5 standard = 62.35)
        if ("hi" %in% names(tbl) && "li" %in% names(tbl)) {
          overall_normal <- 10 * log10(sum((10^(tbl$normal / 10)) * (tbl$hi - tbl$li), na.rm = TRUE))
        } else {
          overall_normal <- 62.35
        }
        
        # Safely extract desensitization flag (default to FALSE if not found)
        desens <- if (!is.null(x$desensitization)) x$desensitization else FALSE
        
        # Recover unaided noise
        unaided_noise <- x$noise - x$gain
        
        # Dynamically recalculate SII for 50 dB SPL (using Normal LTASS scaled down)
        res50 <- sii(speech = tbl$normal + (50 - overall_normal),
                     noise = unaided_noise,
                     threshold = x$threshold,
                     loss = x$loss,
                     freq = tbl$fi,
                     method = method_name,
                     prescription = x$prescription,
                     desensitization = desens,
                     experience = x$experience,
                     gender = x$gender,
                     config = x$config,
                     age = x$age,
                     age_years = x$age_years,
                     coupling = x$coupling,
                     module = x$module,
                     distortion_category = x$distortion_category)
        
        # Dynamically recalculate SII for 65 dB SPL (using Normal LTASS scaled to 65)
        res65 <- sii(speech = tbl$normal + (65 - overall_normal),
                     noise = unaided_noise,
                     threshold = x$threshold,
                     loss = x$loss,
                     freq = tbl$fi,
                     method = method_name,
                     prescription = x$prescription,
                     desensitization = desens,
                     experience = x$experience,
                     gender = x$gender,
                     config = x$config,
                     age = x$age,
                     age_years = x$age_years,
                     coupling = x$coupling,
                     module = x$module,
                     distortion_category = x$distortion_category)
        
        # Dynamically recalculate SII for 80 dB SPL (using Normal LTASS scaled up)
        res80 <- sii(speech = tbl$normal + (80 - overall_normal),
                     noise = unaided_noise,
                     threshold = x$threshold,
                     loss = x$loss,
                     freq = tbl$fi,
                     method = method_name,
                     prescription = x$prescription,
                     desensitization = desens,
                     experience = x$experience,
                     gender = x$gender,
                     config = x$config,
                     age = x$age,
                     age_years = x$age_years,
                     coupling = x$coupling,
                     module = x$module,
                     distortion_category = x$distortion_category)
        
        # Call the insertion gain plotting function
        plot_gain(res50, res65, res80, target_nalnl2 = x$target_nalnl2, target_dsl = x$target_dsl, target_cameq2 = x$target_cameq2, target_level = x$target_level, ...)
        
      } else {
        # Original interpolation diagnostic plot for unaided objects
        plot(
             x=x$freq.orig, 
             y=x$x.orig, 
             col="black", 
             cex=2, 
             lwd=2,
             log="x",
             xlab="Frequency (Hz)", 
             ylab="Threshold of Detection (dB HL)",
             ylim=c(0, 80), 
             xlim=c(250, 8000),
             ...
             ) 
        
        lines( x=x$freq, y=x$table[, "T'i"],
              col="blue", lwd=2, type="o", pch=2)
        abline(v=x$freq, lty=2, col="lightgray")
        legend("topleft",
               legend=c(
                 "Measured data",
                 "Interpolated values"
                 ),
               col=c("black",  "blue"),
               pch=c(      1,     2 ),
               lty=c(     NA,     1 ),
               lwd=c(     NA,     1 ),
               bg="white"
          )
      }
    }
  }

plot_gain <- function(res50, res65, res80, target_nalnl2 = NULL, target_dsl = NULL, target_cameq2 = NULL, target_level = NULL, ...) {
  if (!inherits(res50, "SII") || !inherits(res65, "SII") || !inherits(res80, "SII")) {
    stop("All inputs must be objects of class 'SII'")
  }
  
  freq <- res65$freq
  prescription <- if (!is.null(res65$prescription_name)) res65$prescription_name else
                  if (is.null(res65$prescription)) "Custom" else
                  if (is.character(res65$prescription)) res65$prescription else "Open-NL"
  
  # Calculate insertion gain (Aided Speech - Unaided Speech) for each input level
  # Adding robust max(0, x) to ensure we don't plot negative insertion gain curves
  g50 <- pmax(0, res50$table[, "E'i"] - res50$unaided_speech)
  g65 <- pmax(0, res65$table[, "E'i"] - res65$unaided_speech)
  g80 <- pmax(0, res80$table[, "E'i"] - res80$unaided_speech)
  
  # Keep standard margins
  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))
  
  # Determine bounds
  y_max <- max(c(g50, g65, g80, target_nalnl2, target_dsl, target_cameq2), na.rm=TRUE) + 5
  if (y_max < 20) y_max <- 20
  
  # Setup standard margins, increase bottom margin for CR values
  par(mar = c(6, 4, 4, 2) + 0.1, xpd = FALSE)
  
  plot(
    x = freq,
    y = g65,
    type = "n",
    log = "x",
    xlab = "Frequency (Hz)",
    ylab = "Insertion Gain (dB)",
    ylim = c(0, y_max),
    xlim = c(250, 8000),
    xaxt = "n",
    main = paste("Insertion Gain -", prescription),
    ...
  )
  
  # Draw custom octave x-axis
  axis(1, at = c(250, 500, 1000, 2000, 4000, 8000), labels = c(250, 500, 1000, 2000, 4000, 8000))
  
  # Add vertical dashed lines for octave bands
  octaves <- c(250, 500, 1000, 2000, 4000, 8000)
  abline(v = octaves, lty = 3, col = "lightgray")
  
  # Plot curves
  if (!is.null(target_nalnl2) || !is.null(target_dsl) || !is.null(target_cameq2)) {
    # Preset Benchmark Mode: Plot the specific target_level curve to match UI dropdown
    t_level <- target_level
    if (is.null(t_level)) t_level <- 65
    
    if (t_level == 50) {
      lines(x = freq, y = g50, col = "blue", lwd = 3, lty = 3)
      leg_names <- c(paste(prescription, "(50 dB SPL)"))
      leg_cols <- c("blue")
      leg_lty <- c(3)
    } else if (t_level == 80) {
      lines(x = freq, y = g80, col = "red", lwd = 3, lty = 3)
      leg_names <- c(paste(prescription, "(80 dB SPL)"))
      leg_cols <- c("red")
      leg_lty <- c(2)
    } else {
      lines(x = freq, y = g65, col = "black", lwd = 3, lty = 1)
      leg_names <- c(paste(prescription, "(65 dB SPL)"))
      leg_cols <- c("black")
      leg_lty <- c(1)
    }
  } else {
    # Standard Mode: Plot all 3 compression curves
    lines(x = freq, y = g50, col = "blue", lwd = 2, lty = 3) # Dotted for 50 (Soft)
    lines(x = freq, y = g65, col = "forestgreen", lwd = 2, lty = 1) # Solid for 65 (Avg)
    lines(x = freq, y = g80, col = "red", lwd = 2, lty = 3) # Dotted for 80 (Loud)
    
    leg_names <- c("50 dB SPL (Soft)", "65 dB SPL (Avg)", "80 dB SPL (Loud)")
    leg_cols <- c("blue", "black", "red")
    leg_lty <- c(3, 1, 2)
  }
  
  if (!is.null(target_nalnl2)) {
    lines(x = freq, y = target_nalnl2, col = "purple", lwd = 2, lty = 4)
    leg_names <- c(leg_names, "NAL-NL2 Target")
    leg_cols <- c(leg_cols, "purple")
    leg_lty <- c(leg_lty, 4)
  }
  if (!is.null(target_dsl)) {
    lines(x = freq, y = target_dsl, col = "orange", lwd = 2, lty = 5)
    leg_names <- c(leg_names, "DSL Target")
    leg_cols <- c(leg_cols, "orange")
    leg_lty <- c(leg_lty, 5)
  }
  if (!is.null(target_cameq2)) {
    lines(x = freq, y = target_cameq2, col = "forestgreen", lwd = 2, lty = 6)
    leg_names <- c(leg_names, "CAMEQ2-HF Target")
    leg_cols <- c(leg_cols, "forestgreen")
    leg_lty <- c(leg_lty, 6)
  }
  
  # Add legend inside the plot to prevent clipping
  # Use topright because y_max is padded by +5, guaranteeing empty space at the top!
  legend("topright",
         inset = c(0.02, 0.02),
         legend = leg_names,
         col = leg_cols,
         lty = leg_lty,
         lwd = 2,
         bg = grDevices::rgb(1, 1, 1, 0.85),
         cex = 0.85,
         bty = "o",
         box.col = "lightgray"
    )
    
  # Calculate and display Compression Ratios (between 50 and 80 dB SPL)
  octave_g50 <- approx(x = log10(freq), y = g50, xout = log10(octaves), rule = 2)$y
  octave_g80 <- approx(x = log10(freq), y = g80, xout = log10(octaves), rule = 2)$y
  
  delta_out <- 30 + octave_g80 - octave_g50
  cr_vals <- 30 / pmax(delta_out, 0.01) # avoid div by zero
  cr_strs <- sprintf("%.1f", cr_vals)
  
  mtext("CR:", side = 1, line = 4, at = 150, cex = 0.9, font = 2)
  for (i in seq_along(octaves)) {
    mtext(cr_strs[i], side = 1, line = 4, at = octaves[i], cex = 0.9)
  }
}
