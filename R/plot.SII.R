plot.SII <- function(x, clinical = FALSE, ...)
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
      
      vocal_effort_str <- "Custom"
      if (!is.null(x$vocal_effort)) {
        # Capitalize first letter
        vocal_effort_str <- paste0(toupper(substr(x$vocal_effort, 1, 1)), substring(x$vocal_effort, 2))
      }
      
      line1 <- if (is_aided) paste("Clinical SPLogram - Aided SII:", round(x$sii, 3), " (Unaided:", round(x$unaided_sii, 3), ")") else paste("Clinical SPLogram - SII:", round(x$sii, 3))
      line2 <- paste("Vocal Effort:", vocal_effort_str)
      
      plot_title <- paste(line1, "\n", line2, sep="")
      
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
      # Top of the shaded area is the speech spectrum
      top <- speech
      # Bottom is the masker, but constrained so it doesn't go above the speech
      bottom <- pmin(speech, masker, na.rm=TRUE)
      
      # Remove NAs for polygon
      valid <- !is.na(top) & !is.na(bottom) & !is.na(freq)
      if (any(valid)) {
          graphics::polygon(
            x = c(freq[valid], rev(freq[valid])),
            y = c(top[valid], rev(bottom[valid])),
            col = grDevices::rgb(0.2, 0.8, 0.2, 0.3), # Light transparent green
            border = NA
          )
      }
      
      # Add vertical dashed lines for frequency bands
      abline(v = freq, lty = 3, col = "lightgray")
      
      # Draw lines
      lines(x = freq, y = thresh, col = "red", lwd = 2, type = "l") # Threshold line
      points(x = x$orig[[1]], y = x$orig[[4]], col = "red", pch = 4, lwd = 2, cex = 1.2) # Threshold original points
      
      if (is_aided) {
        lines(x = freq, y = x$unaided_speech, col = "forestgreen", lwd = 2, type = "l", lty = 2) # Unaided Speech
      }
      lines(x = freq, y = speech, col = "forestgreen", lwd = 2, type = "l") # Aided / Final Speech
      
      has_noise <- !is.null(x$call$noise)
      
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
        lines(x = freq, y = noise, col = "darkgray", lwd = 2, type = "l", lty = 2) # Noise
        leg_names <- c(leg_names, "Noise Level (N'i)")
        leg_cols <- c(leg_cols, "darkgray")
        leg_pch <- c(leg_pch, NA)
        leg_lty <- c(leg_lty, 2)
        leg_lwd <- c(leg_lwd, 2)
        leg_cex <- c(leg_cex, 1)
      }
      
      # Always add shaded area to legend at the end
      leg_names <- c(leg_names, "Audible Speech Area")
      leg_cols <- c(leg_cols, grDevices::rgb(0.2, 0.8, 0.2, 0.3))
      leg_pch <- c(leg_pch, 15)
      leg_lty <- c(leg_lty, NA)
      leg_lwd <- c(leg_lwd, NA)
      leg_cex <- c(leg_cex, 2)
      
      legend("topright",
             legend = leg_names,
             col = leg_cols,
             pch = leg_pch,
             lty = leg_lty,
             lwd = leg_lwd,
             pt.cex = leg_cex,
             bg = "white"
        )
      
    } else {
      plot(
           x=x$freq.orig, 
           y=x$x.orig, 
           col="black", 
           cex=2, 
           lwd=2,
           log="x",
           xlab="Frequency (Herz)", 
           ylab="Threshhold of Detection (dB)",
           ylim=c(0, 80), 
           xlim=c(100, 8500),
           ...
           ) 
      
      lines( x=x$freq, y=x$table[, "T'i"],
            col="blue", lwd=2, type="o", pch=2)
      abline(v=x$freq, lty=2)
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
