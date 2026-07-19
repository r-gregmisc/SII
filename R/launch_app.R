#' Launch the SII Interactive Dashboard
#' 
#' @description
#' Launches a local Shiny web application that provides an interactive interface 
#' to the SII calculation engine and plotting utilities.
#' 
#' @details
#' The interactive dashboard allows you to dynamically adjust hearing thresholds 
#' across standard frequencies using sliders. It provides real-time visualization 
#' of the Clinical SPLogram and the Insertion Gain plot based on the selected 
#' prescriptive rationale (e.g., Unaided, NAL-R, Open-NL) and desensitization settings.
#' 
#' @export
launch_app <- function() {
  if (!requireNamespace("shiny", quietly = TRUE) || !requireNamespace("bslib", quietly = TRUE)) {
    stop("Packages 'shiny' and 'bslib' are required to launch the app. Please install them with install.packages(c('shiny', 'bslib'))", call. = FALSE)
  }
  
  app_dir <- system.file("shiny", package = "SII")
  if (app_dir == "") {
    stop("Could not find the 'shiny' directory in the installed package. Try re-installing the package.", call. = FALSE)
  }
  
  shiny::runApp(app_dir, display.mode = "normal")
}
