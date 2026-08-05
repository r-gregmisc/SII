import re

with open('paper.md', 'r') as f:
    content = f.read()

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
    orcid: "0000-0000-0000-0000"
    affiliation: 1
affiliations:
  - name: Wichita State University, Department of Communication Sciences and Disorders, Wichita, USA
    index: 1
bibliography: paper.bib
---"""

if len(parts) >= 3:
    content = yaml_replacement + parts[2]

with open('paper.md', 'w') as f:
    f.write(content)
