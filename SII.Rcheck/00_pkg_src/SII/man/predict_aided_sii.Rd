\name{predict_aided_sii}
\alias{predict_aided_sii}
\title{Predict Aided Speech Intelligibility Index (SII)}
\description{
  Uses multiple linear regression equations from Johnson (2013) to accurately predict 
  the aided Speech Intelligibility Index (SII) for a 65 dB SPL average speech input. 
  The predictions approximate the full 2,160-step ANSI S3.5 calculation based on pure 
  tone averages (PTA).
}
\usage{
predict_aided_sii(freq, threshold, age = c("adult", "pediatric"), prescription = c("NAL-NL2", "DSL"), desensitized = FALSE)
}
\arguments{
  \item{freq}{A numeric vector of frequencies (in Hz) corresponding to the \code{threshold} values.}
  \item{threshold}{A numeric vector of hearing thresholds (in dB HL).}
  \item{age}{A character string specifying the patient age group. Must be either \code{"adult"} (default) or \code{"pediatric"} (modeled on 3-year-olds).}
  \item{prescription}{A character string specifying the prescriptive rationale to predict. Must be either \code{"NAL-NL2"} (default) or \code{"DSL"} (DSL m[i/o] v5.0).}
  \item{desensitized}{Logical flag. If \code{TRUE}, predicts the effective SII incorporating hearing loss desensitization. If \code{FALSE} (default), predicts the traditional ANSI SII.}
}
\value{
  A numeric value representing the predicted SII (constrained between 0.0 and 1.0).
}
\references{
  Johnson, E. E. (2013). Modern prescription theory and application: realistic expectations for speech recognition with hearing aids. Trends in Amplification, 17(3/4), 143-170.
}
\author{
  Maintainer
}
