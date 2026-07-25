\name{calculate_loudness}
\alias{calculate_loudness}
\title{Calculate Loudness (Sones)}
\description{
Calculates the estimated loudness in sones for a given Speech Intelligibility Index (SII) object.
}
\usage{
calculate_loudness(x)
}
\arguments{
  \item{x}{An object of class \code{SII}, representing the output of the \code{sii()} function.}
}
\value{
Returns a numeric value representing the total loudness in sones.
}
\author{Mark Shaver}
\examples{
sii.res <- sii(speech=c(50, 40, 40, 30, 20, 0), threshold=rep(0,6), method="octave")
calculate_loudness(sii.res)
}
