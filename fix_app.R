lines <- readLines("/home/mark/Development/SII for R/SII/inst/shiny/app.R")
start_idx <- grep("observeEvent\\(input\\$preset, \\{", lines)
end_idx <- grep("^  \\}\\)$", lines)
# find the end_idx that comes after start_idx
end_idx <- end_idx[end_idx > start_idx][1]

new_block <- c(
  '  observeEvent(input$preset, {',
  '    if (input$preset == "a1") {',
  '      updateSliderInput(session, "htl250", value = 15)',
  '      updateSliderInput(session, "htl500", value = 20)',
  '      updateSliderInput(session, "htl1000", value = 30)',
  '      updateSliderInput(session, "htl2000", value = 40)',
  '      updateSliderInput(session, "htl4000", value = 50)',
  '      updateSliderInput(session, "htl8000", value = 60)',
  '    } else if (input$preset == "a2") {',
  '      updateSliderInput(session, "htl250", value = 60)',
  '      updateSliderInput(session, "htl500", value = 50)',
  '      updateSliderInput(session, "htl1000", value = 40)',
  '      updateSliderInput(session, "htl2000", value = 30)',
  '      updateSliderInput(session, "htl4000", value = 20)',
  '      updateSliderInput(session, "htl8000", value = 15)',
  '    } else if (input$preset == "a3") {',
  '      updateSliderInput(session, "htl250", value = 10)',
  '      updateSliderInput(session, "htl500", value = 20)',
  '      updateSliderInput(session, "htl1000", value = 40)',
  '      updateSliderInput(session, "htl2000", value = 50)',
  '      updateSliderInput(session, "htl4000", value = 55)',
  '      updateSliderInput(session, "htl8000", value = 60)',
  '    } else if (input$preset == "a4") {',
  '      updateSliderInput(session, "htl250", value = 0)',
  '      updateSliderInput(session, "htl500", value = 0)',
  '      updateSliderInput(session, "htl1000", value = 10)',
  '      updateSliderInput(session, "htl2000", value = 40)',
  '      updateSliderInput(session, "htl4000", value = 70)',
  '      updateSliderInput(session, "htl8000", value = 80)',
  '    } else if (input$preset == "a5") {',
  '      updateSliderInput(session, "htl250", value = 10)',
  '      updateSliderInput(session, "htl500", value = 10)',
  '      updateSliderInput(session, "htl1000", value = 20)',
  '      updateSliderInput(session, "htl2000", value = 60)',
  '      updateSliderInput(session, "htl4000", value = 80)',
  '      updateSliderInput(session, "htl8000", value = 100)',
  '    } else if (input$preset == "a6") {',
  '      updateSliderInput(session, "htl250", value = 50)',
  '      updateSliderInput(session, "htl500", value = 55)',
  '      updateSliderInput(session, "htl1000", value = 60)',
  '      updateSliderInput(session, "htl2000", value = 65)',
  '      updateSliderInput(session, "htl4000", value = 75)',
  '      updateSliderInput(session, "htl8000", value = 80)',
  '    } else if (input$preset == "a7") {',
  '      updateSliderInput(session, "htl250", value = 50)',
  '      updateSliderInput(session, "htl500", value = 50)',
  '      updateSliderInput(session, "htl1000", value = 50)',
  '      updateSliderInput(session, "htl2000", value = 50)',
  '      updateSliderInput(session, "htl4000", value = 50)',
  '      updateSliderInput(session, "htl8000", value = 50)',
  '    }',
  '  })'
)

lines <- c(lines[1:(start_idx-1)], new_block, lines[(end_idx+1):length(lines)])
writeLines(lines, "/home/mark/Development/SII for R/SII/inst/shiny/app.R")
