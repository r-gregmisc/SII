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

# Fix Markdown run-on
content = content.replace(
    '# Implementation and Validation## The ANSI S3.5-1997 Computational Engine',
    '# Implementation and Validation\n\n## The ANSI S3.5-1997 Computational Engine'
)

# Fix AI Statement author name
content = content.replace(
    'The submitting author utilized an LLM assistant',
    'The submitting author (Mark Shaver) utilized an LLM assistant'
)

# Fix install path
content = content.replace(
    "The package can be installed directly from GitHub via `remotes::install_github('euphonic-euphemism/SII')`.",
    "The package can be installed directly from GitHub via `remotes::install_github('euphonic-euphemism/SII')` (the package is intended for GitHub and Zenodo distribution and is not currently planned for CRAN submission)."
)

# Fix Warnes agreement link
content = content.replace(
    "documented agreement to revive the namespace.",
    "documented agreement to revive the namespace (archived in the repository's `NOTICE.md` file)."
)

# Fix "Direct comparison... infeasible"
content = content.replace(
    "direct comparison against an independent reference implementation is currently infeasible due to the lack of open-source counterparts.",
    "no independent open-source implementation of the Chen et al. 2011 nonlinear-filterbank variant specifically exists for direct comparison."
)

# Fix Wasm abbreviation
content = content.replace(
    "WebAssembly (Wasm)",
    "WebAssembly"
)

with open('paper.md', 'w') as f:
    f.write(content)

