\name{sii}
\alias{sii}
\alias{print.SII}
\alias{plot.SII}
\alias{summary.SII}
\title{Compute ANSI/ASA S3.5-1997 (R2024) Speech Intelligibility Index (SII)}
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
    ten_edge_lf=NULL)
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
  \item{prescription}{A character string (e.g. \code{"NAL-R"}, \code{"Open-NL"}). If provided, the function will automatically calculate hearing aid insertion gain based on the specified prescriptive fitting rationale and add it to the speech and noise spectrum, calculating an Aided SII.}
  \item{desensitization}{Logical flag. If \code{TRUE}, applies the hearing loss desensitization factor (Ching et al., 2011; Johnson, 2013) to the calculation to account for suprathreshold distortion in impaired ears. Defaults to \code{FALSE} (Traditional ANSI S3.5 calculation).}
  \item{ldl}{Numeric vector specifying Loudness Discomfort Levels (LDL) in dB HL for each frequency. If \code{NULL}, limits are estimated based on hearing thresholds.}
  \item{gender}{Character string specifying patient gender ("male" or "female"). Used for prescriptive algorithms. Defaults to "male".}
  \item{experience}{Character string specifying user hearing aid experience ("experienced", "new", "power"). Defaults to "experienced".}
  \item{config}{Character string for fitting configuration ("bilateral" or "unilateral"). Defaults to "bilateral".}
  \item{age}{Character string for patient age group (e.g., "adult", "child_0_5", "child_6_11", "child_12_23", "child_24_35", "child_36_59"). Used for RECD corrections and pediatric prescriptive modifications.}
  \item{age_years}{Optional. Integer specifying exact age in years, overriding the categorical `age` bin if provided.}
  \item{age_months}{Optional. Integer specifying exact age in months. Only applies to pediatric RECD scaling.}
  \item{coupling}{Character string specifying the acoustic coupling / vent ("custom_occluded", "double_dome", "tulip_dome", "open_dome", "vent_1mm_solid", "vent_2mm_solid", "vent_3mm_solid", "vent_1mm_hollow", "vent_2mm_hollow", "vent_3mm_hollow"). Modifies low-frequency leakage and insertion gain targets.}
  \item{module}{Character string for hearing aid module ("standard" or other specific module constraints).}
  \item{transducer}{Character string specifying the audiometric transducer used for testing ("inserts" or "supra_aural"). Determines RETSPL and RECD corrections for SPLogram plots.}
  \item{custom_gain}{Numeric vector specifying a custom insertion gain array (in dB) for each frequency. If provided along with \code{prescription="Custom"}, this gain is explicitly applied.}
  \item{measured_wrs}{Numeric value specifying the clinical Word Recognition Score (WRS) in percent (0-100). When provided, invokes the Margolis (2025) speech distortion model.}
  \item{wrs_level}{Numeric value specifying the presentation level (in dB HL or SPL) of the clinical WRS test.}
  \item{distortion_category}{Character string ("Mild", "Moderate", or "Severe") specifying the degree of speech distortion. If \code{NULL}, it is estimated based on \code{measured_wrs} and \code{wrs_level}.}
  \item{ten_edge_hf}{High-frequency dead region edge (optional).}
  \item{ten_edge_lf}{Low-frequency dead region edge (optional).}
  \item{object,x}{SII object}
  \item{digits}{Number of digits to display} 
  \item{clinical}{Logical flag. If \code{TRUE}, plots a patient-friendly clinical SPLogram highlighting the audible speech area. If \code{FALSE} (the default), the behavior depends on whether the object is aided or unaided. For unaided objects, it plots a diagnostic interpolation graph. For aided objects (when a prescription was used), it automatically generates a 3-line Insertion Gain plot for 55, 65, and 75 dB SPL input levels (dynamically loading and scaling the true Normal and Loud LTASS spectra).}
  \item{legend}{Logical flag. If \code{TRUE} (the default), draws a legend on the plot.}
  \item{legend_only}{Logical flag. If \code{TRUE}, suppresses the main plot and only draws the legend in the center of the plotting window. Useful for multi-plot layouts.}
  \item{...}{Optional arguments to \code{print}, \code{summary}, and
    \code{plot} methods} 
}
\details{
    American National Standard ANSI/ASA S3.5-1997 (R2024) ("Methods for Calculation of
    the Speech Intelligibility Index") defines a method for computing a
    physical measure that is highly correlated with the intelligibility
    of speech as evaluated by speech perception tests given a group of
    talkers and listeners. This measure is called the Speech
    Intelligibility Index, or SII. The SII is calculated from acoustical
    measurements of speech and noise.

    The \code{sii} function implements ANSI/ASA S3.5-1997 (R2024) as described in
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
      \item \code{"Open-NL"}: A completely transparent, open-source non-linear fitting algorithm developed specifically for this package. It was designed to serve as an open-source alternative to proprietary modern non-linear clinical targets (such as NAL-NL2 and DSL v5.0). The algorithm calculates insertion gain using the following explicit mathematical steps:
      \enumerate{
        \item \strong{Conductive Component Separation}: If an Air-Bone Gap is present, the purely sensorineural component is isolated for WDRC compression. Linear gain representing 75\% of the conductive loss is added at the end (consistent with NAL-NL2/Johnson).
        \item \strong{Dynamic Base Gain}: The base gain relies on a dynamic multiplier (ranging from 0.43 to 0.48) determined by user experience, combined with empirical NAL-R shaping constants. Severe losses receive a booster, while steep slopes receive a low-frequency penalty to avoid upward spread of masking.
        \item \strong{Dead Region Roll-offs}: High-frequency or low-frequency dead regions trigger a steep 30 dB/octave penalty beyond the viable boundaries to prevent acoustic distortion and feedback.
        \item \strong{Wide Dynamic Range Compression (WDRC)}: A dynamic compression ratio (ranging from 1.0 to 3.0) is applied symmetrically around a 65 dB SPL pivot point. The ratio scales dynamically based on the sensorineural threshold and measured Loudness Discomfort Levels (LDLs).
        \item \strong{Bandwidth Roll-off}: Empirical bandwidth roll-offs are applied to limit unnecessary low/high frequency amplification, with separate curves for adults vs. infants.
        \item \strong{Acoustic Coupling}: Adjustments are applied to the low frequencies depending on the specified venting, dome type, and acoustic seal.
        \item \strong{MPO Limits}: Output is capped by predictive NAL-SSPL90 limits, adjusting for conductive attenuation, with an absolute safety hard cap at 120 dB SPL at the cochlea and a hardware output limit of 135 dB SPL.
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
    \item \strong{Minimal Hearing Loss (MHL) Bypass:} If \code{module == "mhl"} and \eqn{PTA_{.5,1,2,4k} \le 25} dB HL, WDRC is bypassed. Applies flat linear gain interpolated from \eqn{(f, G) = \{(250,0), (500,0), (1k,3), (2k,5), (4k,5), (8k,5)\}} dB, with a 1.5 compression ratio for loud inputs.
    \item \strong{Base Anchor (65 dB SPL Input):} \eqn{g_{65} = \max(0, m \times HTL + C)}, where \eqn{m \in \{0.40, 0.45, 0.50\}} depending on \code{experience}, and \eqn{C} interpolates arrays such as \eqn{\{-8, -1, +3, +1, 0, 0, 0, 0\}} dB evaluated at standard audiometric frequencies.
    \item \strong{Audiometric Profile Corrections:}
      \itemize{
        \item \emph{Steep Slope Knee:} For slopes \eqn{>30} dB/octave, penalizes the "knee" (500-1500 Hz) by up to 6 dB, and boosts frequencies \eqn{\ge 2000} Hz by up to 6 dB.
        \item \emph{Severe-Loss Booster (SLB):} Adds \eqn{\min(15, \max(0, HTL - 60) \times 0.5)} dB. Tapered heavily in mid-frequencies and disabled in dead regions.
      }
    \item \strong{High-Frequency Desensitization:} To prevent distortion, excess gain above a limit is compressed at a 2:1 ratio.
      \itemize{
        \item Adult \eqn{Limit = 30 + 0.4 \times \max(0, HTL - 60)}
        \item Child \eqn{Limit = 40 + 0.5 \times \max(0, HTL - 60)}
      }
    \item \strong{Roll-offs and Dead Regions:}
      \itemize{
        \item \emph{Bandwidth Roll-off:} Multiplies \eqn{g_{65}}. Adults: interpolates \eqn{\{(250Hz, 0.7), (500, 1.0), ..., (6k, 0.8), (8k, 0.5)\}}. Children: 1.0 across all frequencies.
        \item \emph{Dead Regions:} Identifies HF Dead Regions (\eqn{HTL \ge 90} at \eqn{f \ge 1k}) and LF Dead Regions (\eqn{HTL \ge 80} at \eqn{f \le 1k}). Applies a 30 dB/octave penalty beyond viable boundaries (\eqn{1.7 \times f_{e}} for HF, \eqn{0.57 \times f_{e}} for LF).
      }
    \item \strong{Bi-directional WDRC:}
      \itemize{
        \item \emph{Compression Ratio (CR):} \eqn{CR_{base} = 1 + \max(0, HTL - 20) / 40}. For \eqn{HTL > 65}, CR reduces toward 1.0 in low frequencies. Overall bounded strictly to \eqn{\le 1.5} for low frequencies (\eqn{\le 500} Hz) and up to \eqn{2.4} for high frequencies (\eqn{\ge 3000} Hz).
        \item \emph{Compression Threshold (CT):} Interpolated from \eqn{(HTL, CT)}. Adult: \eqn{\{(20HL, 30SPL), ..., (100, 45)\}}. Child: \eqn{\{(20, 25), ..., (100, 40)\}}.
        \item \emph{Aggressive MPO Defense:} For steeply sloping losses (\eqn{>15} dB difference) with low LDLs (\eqn{<100} dB SPL), the formula proactively defends against MPO collision. The \eqn{CT} is aggressively lowered by up to 10 dB, and the \eqn{CR} is forced up by an additional 0.05 per dB of LDL penalty.
        \item \emph{I/O Computation:} Calculates gain at CT (\eqn{G_{CT}}) scaling back from 65 dB SPL pivot. Applies linear gain below CT, and WDRC above CT.
      }
    \item \strong{Empirical Adjustments and Smoothing:}
      \itemize{
        \item \emph{Demographic Boosts:} Child Boost: Interpolates \eqn{(HTL, Boost) = \{(20, 5), (50, 5), (80, 2), (100, 1)\}} dB. Gender: Female \eqn{= -1.5} dB. Config: Unilateral \eqn{= +3.0} dB. Experience: New users with \eqn{PTA > 40} get up to \eqn{-6.0} dB penalty.
        \item \emph{LDL Dynamic Range Mapping:} If \code{ldl} is provided, dynamic range is evaluated. For every 1 dB the measured LDL is lower than predicted, \eqn{g_{65}} is reduced by 0.2 dB and \eqn{CR_{base}} is increased by 0.02.
        \item \emph{Acoustic Coupling:} Subtracts vent leakage (e.g., Open Dome \eqn{= \{-35, -28, -15, -2, 0, 0\}} dB).
        \item Applies a 3-point moving average to the final gain array.
      }
    \item \strong{SSPL90 MPO Limiting:} 
      \itemize{
        \item \eqn{MPO_{heuristic} = 100 + 0.5 \times \max(0, HTL - 40)}.
        \item \eqn{MPO_{safe} = LDL_{spl} - 5}.
        \item \eqn{PTS_{safe\_limit} = 105 + 0.5 \times \max(0, HTL - 50)} (110 for Children).
        \item \eqn{MPO_{final} = \min(120, MPO_{heuristic}, MPO_{safe}, PTS_{safe\_limit})}.
      }
  }
}
\references{
ANSI/ASA S3.5-1997 (R2024), "American National Standard Methods for 
Calculation of the Speech Intelligibility Index" American National
Standards Institute, New York. 

Other software programs for calculating SII are available from
\url{https://sii.to/html/programs.html}.

}
\author{Gregory R. Warnes \email{greg@warnes.net}}
\seealso{ SII Constants: \code{\link{critical}}, and
  \code{\link{sic.critical}} }
\examples{

## Example C.1 from ANSI/ASA S3.5-1997 (R2024) Annex C
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

## Example C.2 from ANSI/ASA S3.5-1997 (R2024) Annex C

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

