import re

with open('paper.md', 'r') as f:
    content = f.read()

# Find the second '---'
parts = content.split('---', 2)

yaml_replacement = """---
title: 'SII: An R package for Speech Intelligibility Index calculation and loudness modeling'
tags:
  - R
  - audiology
  - psychoacoustics
  - hearing loss
  - speech intelligibility
  - ANSI S3.5
date: "4 August 2026"
authors:
  - name: Mark Shaver
    orcid: 0000-0000-0000-0000
    affiliation: 1
affiliations:
  - name: Wichita State University, Department of Communication Sciences and Disorders, Wichita, USA
    index: 1
bibliography: paper.bib
---"""

if len(parts) >= 3:
    # parts[0] is everything before the first --- (should be empty)
    # parts[1] is the old YAML
    # parts[2] is the rest of the document
    content = yaml_replacement + parts[2]
else:
    print("Could not find YAML block")

# Fix ANSI R2012 to R2024
content = content.replace("ANSI S3.5-1997 (R2012)", "ANSI S3.5-1997 (R2024)")

# Restore Chen et al citation in the Loudness Model
content = content.replace("implementing this model. It builds", "implementing the model of Chen et al. [@chen2011]. This model builds")

# Move the availability statement
availability = """

## Availability and Installation

The `SII` package source code, releases, and issue tracker are hosted on GitHub. It can be installed directly via `remotes::install_github('euphonic-euphemism/SII')`. To reclaim the archived namespace, a base version of the package has been submitted to CRAN and is currently under manual review; the full feature set described here will be submitted as an update pending that initial acceptance. A persistent archive of the source code is maintained on Zenodo (DOI: 10.5281/zenodo.21798964). Furthermore, the WebAssembly interactive application can be accessed directly at [euphonic-euphemism.github.io/SII](https://euphonic-euphemism.github.io/SII/).
"""

# Try to find and move it if it's there
if "## Availability and Installation" in content:
    content = content.replace(availability + "\n## Architecture and S3 API", "## Architecture and S3 API")
    content = content.replace("# Acknowledgments", availability + "\n# Acknowledgments")
else:
    # If not there, we insert it
    # We must remove scattered mentions first
    content = content.replace(" The package can be installed directly from GitHub via `remotes::install_github('euphonic-euphemism/SII')`. To reclaim the archived namespace, a base version of the package has been submitted to CRAN and is currently under manual review; the full feature set described here will be submitted as an update pending that initial acceptance.", "")
    content = content.replace("The package source and releases are archived via Zenodo (DOI: 10.5281/zenodo.21798964) under the GPL-3.0 license.", "The package source is distributed under the GPL-3.0 license.")
    content = content.replace("# Acknowledgments", availability + "\n# Acknowledgments")

with open('paper.md', 'w') as f:
    f.write(content)

