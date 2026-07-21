\name{sii}
\alias{sii}
\alias{print.SII}
\alias{plot.SII}
\alias{summary.SII}
\title{Compute ANSI S3.5-1997 Speech Intelligibility Index (SII)}
\description{
  Compute the Speech Intelligibility Index (SII) described by ANSI
  specification S3.5-1997, including extensions for conductive
  hearing loss. Optionally apply interpolation obtain values for the
  required frequencies.
}
\usage{
sii(speech = c("normal", "raised", "loud", "shout"),
    noise, threshold, loss, freq, 
    method = c("critical", "equal-contributing",
               "one-third octave", "octave"),
    importance = c("SII", "NNS", "CID22", "NU6", "DRT",
                   "ShortPassage", "SPIN", "CST"),
    interpolate=FALSE,
    prescription=NULL,
    desensitization=FALSE)
\method{print}{SII}(x, digits=3, ...)
\method{plot}{SII}(x, clinical=FALSE, legend=TRUE, legend_only=FALSE, ...)
\method{summary}{SII}(object, digits=2, ...)
}
\arguments{
  \item{speech}{Either a numeric vector providing \eqn{E'_i}{E'[i]}, the
    equivalent speech spectrum level (in dB) at each frequency, or a
    character string indicating the stated vocal effort corresponding to
    one of the standard standard speech spectrum levels ("normal",
    "raised", "loud", "shout"). Defaults to \code{speech="normal"}
    correspoding to the normal level of stated vocal effort. }
  \item{noise}{A numeric vector providing \eqn{N'_i}{N'[i]}, the
    equivalent noise spectrum level (in dB) at each frequency.  If
    missing, defaults to -50 dB for each frequency.}
  \item{threshold}{A numeric vector providing \eqn{T'_i}{T'[i]}, the
    equivalent hearing threshold level (in dB) at each frequency.  If
    missing, defaults to 0 dB for each frequency.}
  \item{loss}{A numeric vector providing \eqn{J'_i}{J'[i]}, the
    conductive hearing loss level (in dB) at each frequency.  If
    missing, defaults to 0 dB for each frequency.}
  \item{freq}{Vector of frequencies for which \code{speech},
    \code{noise}, \code{threshold}, and/or \code{loss} are specified.
    If \code{interpolate=TRUE}, \code{freq} must be specified.
    Otherwise, it must either match the required value for SII
    calculation method given by argument \code{method}, or be missing,
    in which case it will default to the values required for the
    specified method.}
  \item{method}{A character string specifying the SII calculation
    method ("critical", "one-third octave", "equal-contributing",
    "octave")}
  \item{importance}{Either a numeric vector providing \eqn{F_i}{F[i]},
    the transfer function (importance weights) at each frequency, or a
    character string indicating which transfer function to employ
    ("SII", "NNS", "CID22", "NU6", "DRT", "ShortPassage", "SPIN",
    "CST"). Defaults to the standard SII transfer function,
    \code{importance="SII"}.}
  \item{interpolate}{Logical flag indicating whether to interpolate 
    from the provide measurement values and frequencies to those 
    required by the specified method via linear interpolation on the log
    scale.}
  \item{prescription}{A character string (e.g. \code{"NAL-R"}). If provided, the function will automatically calculate hearing aid insertion gain based on the specified prescriptive fitting rationale and add it to the speech and noise spectrum, calculating an Aided SII.}
  \item{desensitization}{Logical flag. If \code{TRUE}, applies the hearing loss desensitization factor (Ching et al., 2011; Johnson, 2013) to the calculation to account for suprathreshold distortion in impaired ears. Defaults to \code{FALSE} (Traditional ANSI S3.5 calculation).}
  \item{object,x}{SII object}
  \item{digits}{Number of digits to display} 
  \item{clinical}{Logical flag. If \code{TRUE}, plots a patient-friendly clinical SPLogram highlighting the audible speech area. If \code{FALSE} (the default), the behavior depends on whether the object is aided or unaided. For unaided objects, it plots a diagnostic interpolation graph. For aided objects (when a prescription was used), it automatically generates a 3-line Insertion Gain plot for 55, 65, and 75 dB SPL input levels (dynamically loading and scaling the true Normal and Loud LTASS spectra).}
  \item{legend}{Logical flag. If \code{TRUE} (the default), draws a legend on the plot.}
  \item{legend_only}{Logical flag. If \code{TRUE}, suppresses the main plot and only draws the legend in the center of the plotting window. Useful for multi-plot layouts.}
  \item{...}{Optional arguments to \code{print}, \code{summary}, and
    \code{plot} methods} 
}
\details{
    American National Standard ANSI S3.5-1997 ("Methods for Calculation of
    the Speech Intelligibility Index") defines a method for computing a
    physical measure that is highly correlated with the intelligibility
    of speech as evaluated by speech perception tests given a group of
    talkers and listeners. This measure is called the Speech
    Intelligibility Index, or SII. The SII is calculated from acoustical
    measurements of speech and noise.

    The \code{sii} function implements ANSI S3.5-1997 as described in
    the standard, without any attempt to optimize the performance. The
    implementation does, however, include the extension for handling
    conductive hearing loss from Annex A (utilizing the optional
    \code{loss} argument), and for utilizing alternative band weights
    (i.e. transfer function) appropriate for differing message contents
    (e.g. types of speech) as described in Annex B or user-specified
    band weights (utilizing the optional argument \code{importance}).

    Further, this implementation provides a mechanism for
    interpolating/extrapolating available measurements to those required
    for the specified calculation procedure.  When
    \code{interpolate=TRUE}, required values for \code{speech},
    \code{noise}, \code{threshold}, and \code{loss} will be computed 
    using linear interpolation (of the log-scaled data).  In this case,
    missing values may be provided and will be appropriately
    interpolated.
    
    \subsection{Prescriptive Fitting Rationales}{
    If the \code{prescription} argument is provided, the function will dynamically calculate a frequency-specific hearing aid insertion gain and apply it to the speech and noise spectrum, calculating an Aided SII. The following rationales are supported:
    
    \itemize{
      \item \code{"NAL-R"}: A classic linear fitting rationale designed by the National Acoustic Laboratories to maximize speech intelligibility for mild-to-moderate losses. Gain is a linear function of the pure-tone average (PTA) and frequency-specific thresholds.
      \item \code{"Open-NL"}: A completely transparent, open-source non-linear fitting algorithm developed specifically for this package. It was designed to serve as an open-source alternative to proprietary modern non-linear clinical targets (such as DSL v5.0). The algorithm calculates insertion gain using the following explicit mathematical steps:
      \enumerate{
        \item \strong{Linear Base Gain}: Starts with the classic NAL-R linear target: \eqn{G_{base} = X + 0.31 \times HTL + C}, where \eqn{X = 0.15 \times PTA}.
        \item \strong{Boosters}: Adds a High-Frequency Booster (up to +6 dB from 4-8 kHz) and a Severe-Loss Booster (\eqn{+0.5 \times (HTL - 60)} for thresholds > 60 dB HL) to maximize audibility.
        \item \strong{Wide Dynamic Range Compression (WDRC)}: A dynamic compression ratio is applied relative to a "pivot point" (the equivalent speech spectrum level of normal 65 dB SPL conversational speech). 
        \item \strong{Compression Ratios (CR)}: For sounds softer than the pivot, \eqn{CR_{soft} = 1 + (HTL / 100)}. For sounds louder than the pivot, \eqn{CR_{loud} = 1 + (HTL / 50)}. The maximum CR is strictly capped at 3.0 to prevent acoustic distortion.
        \item \strong{MPO Limits}: The final aided output is strictly capped by the predictive NAL-SSPL90 limits (\eqn{MPO = 90 + 0.25 \times HTL}) to ensure the prescribed gain never causes the output to exceed uncomfortable loudness levels.
      }
    }
    }
}
\value{
    The return value is an object of class SII, containing the following
    components:
    \item{call}{Function call used to generate the SII object}
    \item{orig}{List containing original (pre-extrapolation) values for
      \code{freq}, \code{speech}, \code{noise}, \code{threshold}, and
      \code{loss}.}
    \item{speech, noise, threshold, loss, and freq}{Values used in
      calculations (extrapolated if necessary)}
    \item{unaided_speech}{Original speech array before applying any prescriptive gain}
    \item{vocal_effort}{String representing the stated vocal effort}
    \item{gain}{Insertion gain array added to speech and noise when a prescription is used}
    \item{prescription}{The fitting rationale used (if any)}
    \item{unaided_sii}{Calculated SII value before applying the prescriptive gain (if a prescription was used)}
    \item{table}{SII calculation worksheet, containing columns
      corresponding to both Table C.1 and C.2 in Annex C of the
      standard. Table columns are
      \describe{
	\item{Fi}{Center frequency of SII band, Hz}
	\item{E'i}{Spectrum level of equivalent speech, dB}
	\item{N'i}{Spectrum level of equivalent noise, dB}
	\item{T'i}{Equivalent hearing threshold level, dB}
	\item{Vi}{Spectrum level for self-speech masking, dB}
	\item{Bi}{Larger of the specrum levels for equivalent noise and
	  self-speech masking, dB}
	\item{Ci}{Slope per octave (doubling of frequency) of the upward
	  spread of masking, dB/octave}
	\item{Zi}{Spectrum level for equivalent masking, dB}
	\item{Xi}{Spectrum level of internal noise, dB}
	\item{X'i}{Spectrum level of equivalent internal noise, dB}
	\item{Di}{Spectrum level for equivalent disturbance, dB}
	\item{Ui}{Spectrum level of standard speech for normal vocal
	  effort, dB}
	\item{Ji}{Equivalent hearing threshold due to conductive hearing
	  loss, dB}
	\item{Li}{Speech level distortion factor, dB}
	\item{Ki}{Temporary variable used in the calculation of the band
	  auditability function}
	\item{Ai}{Band auditability function}
	\item{Ii}{Band importance function}
	\item{IiAi}{Product of the band importance function (Ii), and band
	  auditability function(Ai)}
      }
    }
    \item{sii}{Calculated SII value}
}
\section{Open-NL Prescription Rationale}{
  \strong{DISCLAIMER:} \code{Open-NL} is an untested, experimental fitting rationale. It is designed to mimic aspects of other generic non-linear fitting rationales (such as NAL-NL2 and DSL v5.0) strictly to promote open research, algorithmic transparency, and rapid iteration within the audiology community. It is not intended for clinical use.

  When \code{prescription = "Open-NL"} is selected, the function calculates and applies this WDRC-optimized rationale to maximize the aided Speech Intelligibility Index.
  
  The mathematical algorithm consists of:
  \enumerate{
    \item \strong{WDRC Base Anchor:} A base 65 dB SPL insertion gain anchor is calculated using a custom modification of the NAL-R linear formula. To preserve audibility while preventing Upward Spread of Masking and Level Distortion for flat losses, it utilizes a flatter low-frequency profile (-8 dB at 250 Hz, -3 dB at 500 Hz).
    \item \strong{Severe-Loss Booster:} For thresholds > 60 dB HL, a gain multiplier is dynamically applied to push audibility through the cochlear desensitization barrier.
    \item \strong{Adaptive High-Frequency Boost:} High-frequency gain (+6 dB at 4000 Hz) is adaptively scaled based on the hearing loss. Mild losses receive 0 dB boost to prevent Level Distortion rollover, while severe losses receive the full boost.
    \item \strong{Bi-directional WDRC:} Gain is dynamically adjusted based on the band-specific input speech level pivoting around a 65 dB normal speech spectrum. Soft inputs receive expansion (CR = 0.6) for listening comfort, while loud inputs receive aggressive compression ($CR = 1 + (Threshold - 20)/25$, capped at 3.0) to protect against ANSI level distortion penalties.
    \item \strong{SSPL90 MPO Limiting:} The final aided speech envelope is safely limited using a predictive NAL-SSPL90 ceiling ($MPO = 90 + 0.25 \times Threshold$). Instead of hard peak clipping, a 10:1 compression ratio is applied to any signal exceeding the MPO, preventing dangerous amplification while preserving the acoustic envelope.
  }
}
\references{
ANSI S3.5-1997, "American National Standard Methods for 
Calculation of the Speech Intelligibility Index" American National
Standards Institute, New York. 

Other software programs for calculating SII are available from
\url{https://sii.to/html/programs.html}.

}
\author{Gregory R. Warnes \email{greg@warnes.net}}
\seealso{ SII Constants: \code{\link{critical}}, and
  \code{\link{sic.critical}} }
\examples{

## Example C.1 from ANSI S3.5-1997 Annex C
sii.C1 <- sii(
              speech   = c(50.0, 40.0, 40.0, 30.0, 20.0,  0.0),
              noise    = c(70.0, 65.0, 45.0, 25.0,  1.0,-15.0),
              threshold= c( 0.0,  0.0,  0.0,  0.0,  0.0,  0.0),
              method="octave"
	      )
sii.C1                        # rounded to 2 digits by default
print(sii.C1$sii, digits=20)  # full precision
summary(sii.C1)               # full details
plot(sii.C1)                  # plot
plot(sii.C1, clinical=TRUE)   # clinical SPLogram plot
## The value given in the Standard is $0.504$.


	      
## Same calculation, but manually specify the frequencies
## and importance function, and use default for threshold

sii.C1 <- sii(
              speech   = c(50.0, 40.0, 40.0, 30.0, 20.0,  0.0),
              noise    = c(70.0, 65.0, 45.0, 25.0,  1.0,-15.0),
              method="octave",
              freq=c(250, 500, 1000, 2000, 4000, 8000),
	      importance=c(0.0617, 0.1671, 0.2373, 0.2648, 0.2142, 0.0549)
	      )
sii.C1	     

## Now perform the calculation using frequency weights for the Connected
## Speech Test (CST)
sii.CST <- sii(
               speech   = c(50.0, 40.0, 40.0, 30.0, 20.0,  0.0),
               noise    = c(70.0, 65.0, 45.0, 25.0,  1.0,-15.0),
               method="octave",
	       importance="CST"
	      )
round(sii.CST$table[,-c(5:7,13)],2)
sii.CST$sii

## Example C.2 from ANSI S3.5-1997 Annex C

sii.C2 <- sii(
              speech   = rep(54.0, 18),
              noise    = c(40.0, 30.0, 20.0, rep(0, 18-3) ),
              threshold= rep(0.0,  18),
              method="one-third"
              )
sii.C2$table[1:3,1:8]
sii.C2

## Interpolation example, for 8 frequencies using NU6 importance
## weight, default values for noise.
sii.left <- sii(
                speech="raised",
                threshold=c(25,25,30,35,45,45,55,60),
                freq=c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000),
                method="critical",
                importance="NU6",
                interpolate=TRUE
                )
sii.left


}

\keyword{math}

