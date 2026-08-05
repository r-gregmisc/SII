import os

files = [
    '/home/mark/Development/SII-github/R/reload.constants.R',
    '/home/mark/Development/SII-github/inst/shiny/R/reload.constants.R'
]

for f in files:
    with open(f, 'r') as file:
        content = file.read()
    
    content = content.replace('if(!require("gdata"))', 'if(!requireNamespace("gdata", quietly = TRUE))')
    
    with open(f, 'w') as file:
        file.write(content)
