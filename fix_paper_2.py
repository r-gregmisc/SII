import re

with open('paper.md', 'r') as f:
    content = f.read()

# Fix YAML header
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

content = re.sub(r'^---.*?^---', yaml_replacement, content, flags=re.MULTILINE|re.DOTALL)

# Fix ANSI R2012 to R2024
content = content.replace("ANSI S3.5-1997 (R2012)", "ANSI S3.5-1997 (R2024)")

# Remove second Chen et al. citation
# "implementation of the non-linear loudness model of Chen et al. [@chen2011]." -> okay.
# Next paragraph: "The package includes a non-linear loudness model, `calculate_loudness()`, implementing the model of Chen et al. [@chen2011]."
content = content.replace("implementing the model of Chen et al. [@chen2011]. This model builds", "implementing this model. It builds")

# Consolidated availability statement
availability = """

## Availability and Installation

The `SII` package source code, releases, and issue tracker are hosted on GitHub. It can be installed directly via `remotes::install_github('euphonic-euphemism/SII')`. To reclaim the archived namespace, a base version of the package has been submitted to CRAN and is currently under manual review; the full feature set described here will be submitted as an update pending that initial acceptance. A persistent archive of the source code is maintained on Zenodo (DOI: 10.5281/zenodo.21798964). Furthermore, the WebAssembly interactive application can be accessed directly at [euphonic-euphemism.github.io/SII](https://euphonic-euphemism.github.io/SII/).
"""

# Replace the scattered install instructions with the consolidated block
content = content.replace(" The package can be installed directly from GitHub via `remotes::install_github('euphonic-euphemism/SII')`. To reclaim the archived namespace, a base version of the package has been submitted to CRAN and is currently under manual review; the full feature set described here will be submitted as an update pending that initial acceptance.", "")
content = content.replace("The package source and releases are archived via Zenodo (DOI: 10.5281/zenodo.21798964) under the GPL-3.0 license.", "The package source is distributed under the GPL-3.0 license.")

content = content.replace("## Architecture and S3 API", availability + "\n## Architecture and S3 API")

with open('paper.md', 'w') as f:
    f.write(content)

