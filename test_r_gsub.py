import subprocess

r_script = """
original_file <- readLines("R/nalr.R")
mod_file <- original_file
bp <- 80
sl <- 0.0

mod_file <- gsub("g_base <- g_base \\\\+ 0\\\\.15 \\\\* pmax\\\\(0, sn_threshold - 60\\\\)", 
                 sprintf("g_base <- g_base + %f * pmax(0, sn_threshold - %d)", sl, bp), 
                 mod_file)

matches <- grep("g_base <- g_base \\\\+", mod_file)
cat("Line after replace:", mod_file[matches[1]], "\\n")
"""

with open("test.R", "w") as f:
    f.write(r_script)
