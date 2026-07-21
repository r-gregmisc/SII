library(shiny)
library(bslib)
library(SII)

# Force source the absolute paths to ensure the latest code is used (overriding the installed package)
tryCatch({
  source("/home/mark/Development/SII for R/SII/R/sii.R")
  source("/home/mark/Development/SII for R/SII/R/nalr.R")
  source("/home/mark/Development/SII for R/SII/R/plot.SII.R")
  source("/home/mark/Development/SII for R/SII/R/predict_aided_sii.R")
  source("/home/mark/Development/SII for R/SII/R/benchmark_targets.R")
}, error = function(e) print(paste("Error sourcing absolute paths:", e$message)))

# Define the Modern UI Layout
ui <- page_sidebar(
  title = "SII Advanced Interactive Dashboard",
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = "#2c3e50"),
  fillable = FALSE,
  
  sidebar = sidebar(
    width = 300,
    accordion(
      open = c("Audiogram Thresholds (dB HL)", "Configuration"),
      accordion_panel(
        "Audiogram Thresholds (dB HL)",
        selectInput("preset", "Load Preset Audiogram:", 
                    choices = c("Custom" = "custom", 
                                "A-1 (Flat Moderate)" = "a1", 
                                "A-2 (Reverse Slope)" = "a2", 
                                "A-3 (Cookie Bite)" = "a3", 
                                "A-4 (Steep Sloping)" = "a4"),
                    selected = "custom"),
        sliderInput("htl250", "250 Hz", min = 0, max = 120, value = 20, step = 5),
        sliderInput("htl500", "500 Hz", min = 0, max = 120, value = 30, step = 5),
        sliderInput("htl1000", "1000 Hz", min = 0, max = 120, value = 45, step = 5),
        sliderInput("htl2000", "2000 Hz", min = 0, max = 120, value = 60, step = 5),
        sliderInput("htl4000", "4000 Hz", min = 0, max = 120, value = 75, step = 5),
        sliderInput("htl8000", "8000 Hz", min = 0, max = 120, value = 80, step = 5)
      ),
      accordion_panel(
        "Loudness Discomfort (dB HL)",
        checkboxInput("use_ldl", "Use Measured LDLs?", value = FALSE),
        conditionalPanel(
          condition = "input.use_ldl == true",
          sliderInput("ldl250", "250 Hz", min = 60, max = 130, value = 100, step = 5),
          sliderInput("ldl500", "500 Hz", min = 60, max = 130, value = 100, step = 5),
          sliderInput("ldl1000", "1000 Hz", min = 60, max = 130, value = 100, step = 5),
          sliderInput("ldl2000", "2000 Hz", min = 60, max = 130, value = 100, step = 5),
          sliderInput("ldl4000", "4000 Hz", min = 60, max = 130, value = 100, step = 5),
          sliderInput("ldl8000", "8000 Hz", min = 60, max = 130, value = 100, step = 5)
        )
      ),
      accordion_panel(
        "Configuration",
        radioButtons("speech_level", "Speech Input Level (SPLogram):", 
                     choices = c("55 dB SPL (Soft)" = "55", "65 dB SPL (Average)" = "65", "75 dB SPL (Loud)" = "75"),
                     selected = "65"),
        selectInput("prescription", "Fitting Rationale:", 
                    choices = c("Unaided" = "none", "NAL-R" = "NAL-R", "Open-NL" = "Open-NL"),
                    selected = "Open-NL"),
        selectInput("module", "Operating Module:",
                    choices = c("Standard (Everyday)" = "standard", 
                                "Comfort in Noise (CIN)" = "cin", 
                                "Minimal Hearing Loss (MHL)" = "mhl"),
                    selected = "standard"),
        checkboxInput("desensitization", "Apply Desensitization (Johnson 2013)", value = FALSE)
      ),
      accordion_panel(
        "Demographics & Fitting",
        selectInput("gender", "Gender:", choices = c("Male" = "male", "Female" = "female"), selected = "male"),
        selectInput("age", "Age Group:", 
                    choices = c("Adult (>5 years)" = "adult", 
                                "Child: 36-59 months" = "child_36_59",
                                "Child: 24-35 months" = "child_24_35",
                                "Child: 12-23 months" = "child_12_23",
                                "Child: 6-11 months" = "child_6_11",
                                "Child: 0-5 months" = "child_0_5"), 
                    selected = "adult"),
        selectInput("experience", "Experience:", 
                    choices = c("Power User" = "power", "Experienced User" = "experienced", "New User" = "new"), 
                    selected = "experienced"),
        selectInput("config", "Fitting Configuration:", choices = c("Bilateral (Both Ears)" = "bilateral", "Unilateral (One Ear)" = "unilateral"), selected = "bilateral"),
        selectInput("coupling", "Acoustic Coupling / Vent:", 
                    choices = c("Custom Solid Earmold" = "custom_occluded", 
                                "Double Dome" = "double_dome", 
                                "Tulip Dome" = "tulip_dome", 
                                "Open Dome" = "open_dome"), 
                    selected = "custom_occluded"),
        selectInput("transducer", "Audiometric Transducer:", 
                    choices = c("Insert Earphones (ER-3A)" = "inserts", 
                                "Supra-aural Headphones (TDH-39)" = "supra_aural"),
                    selected = "inserts")
      )
    )
  ),
  
  layout_columns(
    col_widths = c(12),
    card(
      full_screen = TRUE,
      card_header("Clinical SPLogram"),
      plotOutput("splogram", height = "600px")
    ),
    card(
      full_screen = TRUE,
      card_header("Insertion Gain / Plot"),
      plotOutput("gain_plot", height = "600px")
    ),
    card(
      full_screen = TRUE,
      card_header("Prescription Benchmark Comparison"),
      tableOutput("comparison_table")
    )
  )
)

# Helper to estimate Loudness for proprietary prescriptions
estimate_proxy_loudness <- function(base_obj, unaided_obj, target_sii) {
  if (is.na(target_sii)) return(NA)
  
  if (abs(target_sii - base_obj$sii) < 0.001) {
    return(calculate_loudness(base_obj))
  }
  
  sii_error <- function(shift_dB) {
    shifted_speech <- base_obj$speech + shift_dB
    temp_obj <- sii(speech = shifted_speech, 
                    threshold = base_obj$threshold,
                    freq = base_obj$freq,
                    prescription = NULL,
                    desensitization = base_obj$desensitization)
    return(temp_obj$sii - target_sii)
  }
  
  shift_dB <- 0
  lower_val <- sii_error(-60)
  upper_val <- sii_error(60)
  
  if (lower_val * upper_val <= 0) {
    try({
      res <- uniroot(sii_error, lower = -60, upper = 60)
      shift_dB <- res$root
    }, silent = TRUE)
  } else {
    sii_diff <- base_obj$sii - unaided_obj$sii
    sone_diff <- calculate_loudness(base_obj) - calculate_loudness(unaided_obj)
    if (sii_diff != 0) {
      return(calculate_loudness(unaided_obj) + sone_diff * (target_sii - unaided_obj$sii) / sii_diff)
    }
  }
  
  shifted_speech <- base_obj$speech + shift_dB
  proxy_obj <- sii(speech = shifted_speech, 
                   threshold = base_obj$threshold,
                   freq = base_obj$freq,
                   prescription = NULL, 
                   desensitization = base_obj$desensitization)
                   
  return(calculate_loudness(proxy_obj))
}

# Define the Application Logic
server <- function(input, output, session) {
  
  # Static standard data setup
  setup_data <- reactive({
    data("critical", package="SII")
    f_21 <- critical$fi
    overall_normal <- 10 * log10(sum(10^(critical$normal/10)))
    list(f_21 = f_21, normal_spectrum = critical$normal, overall_normal = overall_normal)
  })
  
  # Handle Presets
  observeEvent(input$preset, {
    if (input$preset == "a1") {
      updateSliderInput(session, "htl250", value = 50)
      updateSliderInput(session, "htl500", value = 50)
      updateSliderInput(session, "htl1000", value = 50)
      updateSliderInput(session, "htl2000", value = 50)
      updateSliderInput(session, "htl4000", value = 50)
      updateSliderInput(session, "htl8000", value = 50)
    } else if (input$preset == "a2") {
      updateSliderInput(session, "htl250", value = 50)
      updateSliderInput(session, "htl500", value = 40)
      updateSliderInput(session, "htl1000", value = 30)
      updateSliderInput(session, "htl2000", value = 20)
      updateSliderInput(session, "htl4000", value = 10)
      updateSliderInput(session, "htl8000", value = 10)
    } else if (input$preset == "a3") {
      updateSliderInput(session, "htl250", value = 20)
      updateSliderInput(session, "htl500", value = 40)
      updateSliderInput(session, "htl1000", value = 50)
      updateSliderInput(session, "htl2000", value = 50)
      updateSliderInput(session, "htl4000", value = 40)
      updateSliderInput(session, "htl8000", value = 20)
    } else if (input$preset == "a4") {
      updateSliderInput(session, "htl250", value = 10)
      updateSliderInput(session, "htl500", value = 10)
      updateSliderInput(session, "htl1000", value = 20)
      updateSliderInput(session, "htl2000", value = 50)
      updateSliderInput(session, "htl4000", value = 80)
      updateSliderInput(session, "htl8000", value = 80)
    }
  })
  
  # Reactive SII Calculation triggers every time a slider is moved
  sii_obj <- reactive({
    req(input$htl250)
    d <- setup_data()
    
    # 1. Grab thresholds from sliders
    f_htl <- c(250, 500, 1000, 2000, 4000, 8000)
    threshold <- c(input$htl250, input$htl500, input$htl1000, 
                   input$htl2000, input$htl4000, input$htl8000)
    
    # 2. Interpolate to 21 critical bands
    htl_21 <- approx(x = log10(f_htl), y = threshold, xout = log10(d$f_21), rule = 2)$y
    
    # 3. Handle prescription
    presc <- if (input$prescription == "none") NULL else input$prescription
    
    # 3.5 Handle LDLs
    if (isTRUE(input$use_ldl)) {
      ldl_input <- c(input$ldl250, input$ldl500, input$ldl1000, 
                     input$ldl2000, input$ldl4000, input$ldl8000)
      ldl_21 <- approx(x = log10(f_htl), y = ldl_input, xout = log10(d$f_21), rule = 2)$y
    } else {
      ldl_21 <- NULL
    }
    
    # 3.8 Calculate specific speech spectrum based on user input
    target_level <- as.numeric(input$speech_level)
    speech_input <- d$normal_spectrum + (target_level - d$overall_normal)
    
    # 4. Run the robust SII calculation engine
    obj <- sii(speech = speech_input, 
        threshold = htl_21, 
        freq = d$f_21, 
        prescription = presc, 
        desensitization = input$desensitization,
        ldl = ldl_21,
        gender = input$gender,
        experience = input$experience,
        config = input$config,
        age = input$age,
        coupling = input$coupling,
        module = input$module,
        transducer = input$transducer)
        
    # Append JD2011 targets for plotting if a preset is selected
    preset <- input$preset
    target_level <- as.numeric(input$speech_level)
    if (preset %in% c("a1", "a2", "a3", "a4") && !is.null(presc) && presc == "Open-NL") {
      obj$target_nalnl2 <- get_jd2011_target(preset, "NAL-NL2", d$f_21, target_level)
      obj$target_dsl <- get_jd2011_target(preset, "DSL", d$f_21, target_level)
    }
    
    obj$target_level <- target_level
    
    return(obj)
  })
  
  # Render the SPLogram Plot
  output$splogram <- renderPlot({
    obj <- sii_obj()
    # The clinical=TRUE flag builds the complex clinical SPLogram graph
    plot(obj, clinical = TRUE)
  })
  
  # Render the Insertion Gain Plot
  output$gain_plot <- renderPlot({
    obj <- sii_obj()
    # The clinical=FALSE flag automatically intercepts aided objects to draw 
    # the 3-line Insertion Gain compression curves for 55, 65, and 75 dB SPL!
    plot(obj, clinical = FALSE)
  })
  
  # Render the Benchmark Comparison Table
  output$comparison_table <- renderTable({
    req(input$htl250)
    d <- setup_data()
    f_htl <- c(250, 500, 1000, 2000, 4000, 8000)
    threshold <- c(input$htl250, input$htl500, input$htl1000, 
                   input$htl2000, input$htl4000, input$htl8000)
    htl_21 <- approx(x = log10(f_htl), y = threshold, xout = log10(d$f_21), rule = 2)$y
    
    # Calculate Speech Input at selected level
    target_level <- as.numeric(input$speech_level)
    speech_input <- d$normal_spectrum + (target_level - d$overall_normal)
    
    # Calculate Unaided
    obj_unaided <- sii(speech = speech_input, threshold = htl_21, freq = d$f_21, prescription = NULL, 
                       desensitization = input$desensitization, transducer = input$transducer)
    
    # Calculate NAL-R
    obj_nalr <- sii(speech = speech_input, threshold = htl_21, freq = d$f_21, prescription = "NAL-R", 
                    desensitization = input$desensitization, transducer = input$transducer)
    
    # Calculate Open-NL
    obj_opennl <- sii(speech = speech_input, threshold = htl_21, freq = d$f_21, prescription = "Open-NL", 
                      desensitization = input$desensitization, 
                      gender = input$gender, experience = input$experience, 
                      config = input$config, age = input$age, 
                      coupling = input$coupling, module = input$module, transducer = input$transducer)
    
    # Predict NAL-NL2 and DSL v5.0
    preset <- input$preset
    if (preset %in% c("a1", "a2", "a3", "a4")) {
      target_nalnl2 <- get_jd2011_target(preset, "NAL-NL2", d$f_21, target_level)
      target_dsl <- get_jd2011_target(preset, "DSL", d$f_21, target_level)
      obj_nalnl2 <- sii(speech = speech_input, threshold = htl_21, freq = d$f_21, custom_gain = target_nalnl2, desensitization = input$desensitization, transducer = input$transducer)
      obj_dsl <- sii(speech = speech_input, threshold = htl_21, freq = d$f_21, custom_gain = target_dsl, desensitization = input$desensitization, transducer = input$transducer)
      val_nalnl2_sii <- obj_nalnl2$sii
      val_dsl_sii <- obj_dsl$sii
      val_nalnl2_sones <- calculate_loudness(obj_nalnl2)
      val_dsl_sones <- calculate_loudness(obj_dsl)
      name_nalnl2 <- "NAL-NL2 (JD2011)"
      name_dsl <- "DSL v5.0 (JD2011)"
    } else {
      val_nalnl2_sii <- predict_aided_sii(freq = f_htl, threshold = threshold, prescription = "NAL-NL2", desensitized = input$desensitization)
      val_dsl_sii <- predict_aided_sii(freq = f_htl, threshold = threshold, prescription = "DSL", desensitized = input$desensitization)
      
      val_nalnl2_sones <- estimate_proxy_loudness(obj_opennl, obj_unaided, val_nalnl2_sii)
      val_dsl_sones <- estimate_proxy_loudness(obj_opennl, obj_unaided, val_dsl_sii)
      name_nalnl2 <- "NAL-NL2 (Predicted)"
      name_dsl <- "DSL v5.0 (Predicted)"
    }
    
    data.frame(
      Prescription = c("Unaided", "NAL-R", "Open-NL", name_nalnl2, name_dsl),
      SII = sprintf("%.3f", c(obj_unaided$sii, obj_nalr$sii, obj_opennl$sii, val_nalnl2_sii, val_dsl_sii)),
      Sones = c(sprintf("%.1f", calculate_loudness(obj_unaided)), 
                sprintf("%.1f", calculate_loudness(obj_nalr)), 
                sprintf("%.1f", calculate_loudness(obj_opennl)), 
                sprintf("%.1f", val_nalnl2_sones), 
                sprintf("%.1f", val_dsl_sones))
    )
  }, align = "c")
}

# Launch the Application 
shinyApp(ui = ui, server = server)
