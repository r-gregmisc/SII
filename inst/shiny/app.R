library(shiny)
library(bslib)
library(SII)

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
        sliderInput("htl250", "250 Hz", min = 0, max = 120, value = 20, step = 5),
        sliderInput("htl500", "500 Hz", min = 0, max = 120, value = 30, step = 5),
        sliderInput("htl1000", "1000 Hz", min = 0, max = 120, value = 45, step = 5),
        sliderInput("htl2000", "2000 Hz", min = 0, max = 120, value = 60, step = 5),
        sliderInput("htl4000", "4000 Hz", min = 0, max = 120, value = 75, step = 5),
        sliderInput("htl8000", "8000 Hz", min = 0, max = 120, value = 80, step = 5)
      ),
      accordion_panel(
        "Configuration",
        selectInput("prescription", "Fitting Rationale:", 
                    choices = c("Unaided" = "none", "NAL-R" = "NAL-R", "Open-NL" = "Open-NL"),
                    selected = "Open-NL"),
        checkboxInput("desensitization", "Apply Desensitization (Johnson 2013)", value = TRUE)
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

# Define the Application Logic
server <- function(input, output, session) {
  
  # Static standard data setup
  setup_data <- reactive({
    data("critical", package="SII")
    f_21 <- critical$fi
    overall_normal <- 10 * log10(sum(10^(critical$normal/10)))
    speech_65 <- critical$normal + (65 - overall_normal)
    list(f_21 = f_21, speech_65 = speech_65)
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
    
    # 4. Run the robust SII calculation engine
    sii(speech = d$speech_65, 
        threshold = htl_21, 
        freq = d$f_21, 
        prescription = presc, 
        desensitization = input$desensitization)
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
    
    # Calculate Unaided
    obj_unaided <- sii(speech = d$speech_65, threshold = htl_21, freq = d$f_21, prescription = NULL, desensitization = input$desensitization)
    
    # Calculate NAL-R
    obj_nalr <- sii(speech = d$speech_65, threshold = htl_21, freq = d$f_21, prescription = "NAL-R", desensitization = input$desensitization)
    
    # Calculate Open-NL
    obj_opennl <- sii(speech = d$speech_65, threshold = htl_21, freq = d$f_21, prescription = "Open-NL", desensitization = input$desensitization)
    
    # Predict NAL-NL2 and DSL v5.0
    pred_nalnl2 <- predict_aided_sii(freq = f_htl, threshold = threshold, prescription = "NAL-NL2", desensitized = input$desensitization)
    pred_dsl <- predict_aided_sii(freq = f_htl, threshold = threshold, prescription = "DSL", desensitized = input$desensitization)
    
    data.frame(
      Prescription = c("Unaided", "NAL-R", "Open-NL", "NAL-NL2 (Predicted)", "DSL v5.0 (Predicted)"),
      SII = sprintf("%.3f", c(obj_unaided$sii, obj_nalr$sii, obj_opennl$sii, pred_nalnl2, pred_dsl)),
      Sones = c(sprintf("%.1f", calculate_loudness(obj_unaided)), 
                sprintf("%.1f", calculate_loudness(obj_nalr)), 
                sprintf("%.1f", calculate_loudness(obj_opennl)), 
                "N/A", "N/A")
    )
  }, align = "c")
}

# Launch the Application 
shinyApp(ui = ui, server = server)
