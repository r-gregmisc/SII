\name{launch_app}
\alias{launch_app}
\title{Launch the SII Interactive Dashboard}
\description{
Launches a local Shiny web application that provides an interactive graphical interface to the SII calculation engine and plotting utilities.
}
\usage{
launch_app()
}
\details{
The interactive dashboard allows you to dynamically adjust hearing thresholds across standard clinical frequencies (250 Hz - 8000 Hz) using sliders. It provides real-time visualization of the Clinical SPLogram and the Insertion Gain / Compression plot based on the selected prescriptive rationale (e.g., Unaided, NAL-R, Open-NL) and desensitization settings.

Note: This function requires the \code{shiny} and \code{bslib} packages to be installed.
}
\author{
Gregory R. Warnes \email{greg@warnes.net}, Mark Shaver \email{mark.shaver@posteo.net}
}
\seealso{
\code{\link{sii}}, \code{\link{plot.SII}}
}
\examples{
\dontrun{
  # Launch the interactive SII dashboard in your web browser
  launch_app()
}
}
\keyword{misc}
