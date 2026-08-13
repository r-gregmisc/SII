\name{open_nl}
\alias{open_nl}
\alias{print.prescription_target}
\alias{summary.prescription_target}
\alias{plot.prescription_target}
\title{Open-NL WDRC Gain Prescription}
\description{
  Calculates experimental prescriptive insertion gain and SSPL90 targets for a given hearing loss, based on a rule-based WDRC heuristic.
}
\usage{
open_nl(speech = 65, threshold, freq, gender = "male", experience = "experienced",
        config = "bilateral", age = "adult", coupling = "custom_occluded",
        module = "standard", ldl = NULL, age_years = NULL, age_months = NULL,
        loss = NULL, distortion_category = NULL, ten_edge_hf = NULL, ten_edge_lf = NULL,
        user_cr = NULL, optimize = TRUE, seed_noise = NULL, optim_method = "Nelder-Mead")
\method{print}{prescription_target}(x, ...)
\method{summary}{prescription_target}(object, ...)
\method{plot}{prescription_target}(x, ...)
}
\arguments{
  \item{speech}{Input speech spectrum level at each frequency. If a single number is provided, it's assumed to be the overall broadband SPL.}
  \item{threshold}{Hearing threshold level at each frequency.}
  \item{freq}{Frequencies at which the thresholds are measured.}
  \item{gender}{Gender of the patient ("male", "female").}
  \item{experience}{Hearing aid experience ("new", "experienced", "power").}
  \item{config}{Fitting configuration ("unilateral", "bilateral").}
  \item{age}{Age group ("adult", "child_0_5", "child_6_11", "child_12_23", "child_24_35", "child_36_59", "child_60_plus").}
  \item{coupling}{Acoustic coupling ("custom_occluded", "open_dome", "tulip_dome", "double_dome", "vent_1mm_solid", etc.).}
  \item{module}{Fitting module ("standard", "cin", "mhl").}
  \item{ldl}{Loudness Discomfort Levels (optional).}
  \item{age_years}{Age in years (optional).}
  \item{age_months}{Age in months (optional).}
  \item{loss}{Conductive hearing loss component (optional).}
  \item{distortion_category}{Distortion category ("Normal", "Low", "Moderate", "High").}
  \item{ten_edge_hf}{High-frequency dead region edge (optional).}
  \item{ten_edge_lf}{Low-frequency dead region edge (optional).}
  \item{user_cr}{User defined compression ratio (optional).}
  \item{optimize}{Optimization flag.}
  \item{seed_noise}{Random noise for optimizer seeding.}
  \item{optim_method}{Optimization method.}
  \item{x,object}{A \code{prescription_target} object.}
  \item{\dots}{Additional graphical or printing parameters.}
}
\value{
  An object of class \code{prescription_target}.
}
\details{
  This experimental function generates non-linear prescriptive targets for research and modeling purposes. It is not intended for clinical use.
}
\author{
  Mark Shaver
}
