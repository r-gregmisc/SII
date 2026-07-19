plot.SII <- function(x, clinical = FALSE, legend = TRUE, legend_only = FALSE, ...)
  {
    if (clinical) {
      freq <- x$freq
      speech <- x$table[, "E'i"]
      noise <- x$table[, "N'i"]
      thresh <- x$table[, "T'i"]
      
      # The masking threshold is the maximum of the internal/external noise and hearing threshold
      masker <- pmax(noise, thresh, na.rm=TRUE)
      
      # Determine bounds for the plot
      y_min <- 0 # Start Y axis at 0 dB SPL
      y_max <- max(c(100, thresh, noise, speech), na.rm=TRUE) + 10
      
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
         leg_names[1] <- paste("Aided Speech Level (", x$prescription, ")", sep="")
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
      
      leg_names <- c(leg_names, "Audible Speech Area")
      leg_cols <- c(leg_cols, grDevices::rgb(0.2, 0.8, 0.2, 0.3))
      leg_pch <- c(leg_pch, 15)
      leg_lty <- c(leg_lty, NA)
      leg_lwd <- c(leg_lwd, NA)
      leg_cex <- c(leg_cex, 2)
      
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
           y = thresh, 
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
      
      # Shade the audible speech area
      top <- speech
      bottom <- pmin(speech, masker, na.rm=TRUE)
      
      valid <- !is.na(top) & !is.na(bottom) & !is.na(freq)
      if (any(valid)) {
          graphics::polygon(
            x = c(freq[valid], rev(freq[valid])),
            y = c(top[valid], rev(bottom[valid])),
            col = grDevices::rgb(0.2, 0.8, 0.2, 0.3),
            border = NA
          )
      }
      
      # Add vertical dashed lines for frequency bands
      abline(v = freq, lty = 3, col = "lightgray")
      
      # Draw lines
      lines(x = freq, y = thresh, col = "red", lwd = 2, type = "l")
      
      # Draw exactly 6 threshold markers on the standard clinical octaves
      octaves <- c(250, 500, 1000, 2000, 4000, 8000)
      orig_freqs <- x$orig[[1]]
      orig_thresh <- x$orig[[4]]
      
      # Re-interpolate original thresholds onto the exact octave grid
      octave_thresh <- approx(x = log10(orig_freqs), y = orig_thresh, xout = log10(octaves), rule = 2)$y
      points(x = octaves, y = octave_thresh, col = "red", pch = 4, lwd = 2, cex = 1.2)
      
      if (is_aided) {
        lines(x = freq, y = x$unaided_speech, col = "forestgreen", lwd = 2, type = "l", lty = 2)
      }
      lines(x = freq, y = speech, col = "forestgreen", lwd = 2, type = "l")
      
      if (has_noise) {
        lines(x = freq, y = noise, col = "darkgray", lwd = 2, type = "l", lty = 2)
      }
      
      if (legend) {
        legend("topright",
               legend = leg_names,
               col = leg_cols,
               pch = leg_pch,
               lty = leg_lty,
               lwd = leg_lwd,
               pt.cex = leg_cex,
               bg = "white",
               cex = 0.75
          )
      }
      
    } else {
      # If clinical=FALSE and the object is aided, show the 3-line Insertion Gain Plot
      if (!is.null(x$prescription)) {
        
        # Determine which calculation method was used to fetch the correct standard spectra
        n_bands <- length(x$freq)
        tbl_name <- if (n_bands == 21) "critical" else 
                    if (n_bands == 18) "onethird" else 
                    if (n_bands == 17) "equal" else "octave"
        
        # Create a local environment to load the data to avoid cluttering the workspace
        local_env <- new.env()
        data(list = tbl_name, package = "SII", envir = local_env)
        tbl <- get(tbl_name, envir = local_env)
        
        # Calculate overall dB SPL levels of the standard Normal and Loud spectra
        overall_normal <- 10 * log10(sum(10^(tbl$normal / 10)))
        overall_loud <- 10 * log10(sum(10^(tbl$loud / 10)))
        
        # Safely extract desensitization flag (default to FALSE if not found)
        desens <- if (!is.null(x$desensitization)) x$desensitization else FALSE
        
        # Recover unaided noise
        unaided_noise <- x$noise - x$gain
        
        # Dynamically recalculate SII for 55 dB SPL (using Normal LTASS scaled down)
        res55 <- sii(speech = tbl$normal + (55 - overall_normal),
                     noise = unaided_noise,
                     threshold = x$threshold,
                     loss = x$loss,
                     freq = tbl$fi,
                     method = tbl_name,
                     prescription = x$prescription,
                     desensitization = desens)
        
        # Dynamically recalculate SII for 65 dB SPL (using Normal LTASS scaled to 65)
        res65 <- sii(speech = tbl$normal + (65 - overall_normal),
                     noise = unaided_noise,
                     threshold = x$threshold,
                     loss = x$loss,
                     freq = tbl$fi,
                     method = tbl_name,
                     prescription = x$prescription,
                     desensitization = desens)
        
        # Dynamically recalculate SII for 75 dB SPL (using Loud LTASS scaled to 75)
        res75 <- sii(speech = tbl$loud + (75 - overall_loud),
                     noise = unaided_noise,
                     threshold = x$threshold,
                     loss = x$loss,
                     freq = tbl$fi,
                     method = tbl_name,
                     prescription = x$prescription,
                     desensitization = desens)
        
        # Call the insertion gain plotting function
        plot_gain(res55, res65, res75, ...)
        
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

plot_gain <- function(res55, res65, res75, ...) {
  if (!inherits(res55, "SII") || !inherits(res65, "SII") || !inherits(res75, "SII")) {
    stop("All inputs must be objects of class 'SII'")
  }
  
  freq <- res65$freq
  g55 <- res55$gain
  g65 <- res65$gain
  g75 <- res75$gain
  
  prescription <- res65$prescription
  if (is.null(prescription)) prescription <- "Custom"
  
  # Determine bounds
  y_max <- max(c(g55, g65, g75), na.rm=TRUE) + 5
  if (y_max < 20) y_max <- 20
  
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
  
  # Add vertical dashed lines for frequency bands
  abline(v = freq, lty = 3, col = "lightgray")
  
  # Plot curves
  lines(x = freq, y = g55, col = "blue", lwd = 2, lty = 3) # Dotted for 55 (Soft)
  lines(x = freq, y = g65, col = "black", lwd = 2, lty = 1) # Solid for 65 (Average)
  lines(x = freq, y = g75, col = "red", lwd = 2, lty = 2) # Dashed for 75 (Loud)
  
  # Add legend
  legend("topleft",
         legend = c("55 dB SPL (Soft)", "65 dB SPL (Average)", "75 dB SPL (Loud)"),
         col = c("blue", "black", "red"),
         lty = c(3, 1, 2),
         lwd = 2,
         bg = "white"
  )
}
