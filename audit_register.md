# Audit register — 2026-09-18 / 19

Session auditing the Open-NL optimizer and the AUDMOD loudness engine ahead of
the JAAA manuscript revision. Runs on branch `audmod-port` at `0885dd7`;
manuscript edits on `manuscript-audit-edits`.

Scripts were written ad hoc and run from `~/Downloads`. They should live in
`reproducibility_scripts/audit/` and be committed alongside their logs, since
several findings below rest on them.

---

## 1. Scripts run

| # | Script | Run at | Log / output | Purpose |
|---|---|---|---|---|
| 1 | `diagnose_multistart.R` | 18th 12:20 | `output/diagnostics_multistart_2026-09-18.log` | Multi-start selection anomaly (todo §2) |
| 2 | `audit_step1.R` | 18th 16:52 | `output/audit_step1_2026-09-18.log` | Loudness API discovery; per-start objective + penalty decomposition |
| 3 | `audit_loudness.R` | 18th 17:19 | `output/audit_loudness_2026-09-18.log` | Spectrum pipeline reconciliation; AUDMOD sanity checks; cap binding |
| 4 | `audit_loudness2.R` | 18th 18:54 | `output/audit_loudness2_2026-09-18.log` | Tone construction; JD2011 profiles; cap binding at budget caps |
| 5 | `rebuild_isoloudness.R` | 18th 19:23–20:17 | `output/isoloudness/isoloudness_2026-09-18.csv` + log | Rebuild the floor contrast without rectification, 3 starts |
| 6 | `starts_sensitivity.R` | 19th 07:15–08:30 | `output/isoloudness/starts_sensitivity_2026-09-19.csv` + log | Does the `d_SII` noise band shrink with more restarts? |
| 7 | `audit_tone_anchor.R` | 19th 08:55 | `output/audit_tone_anchor_2026-09-19.log` | Is the 1-sone anchor failure spectral resampling loss? |
| 8 | `audit_cap_basis.R` | 19th 09:38 | `output/audit_cap_basis_2026-09-19.log` | Which engine produced the manuscript's sone values; what NAL-NL2 targets |

Running / not yet run:

| Script | Status | Notes |
|---|---|---|
| `rebuild_isoloudness_20.R` | running 19th, ~6h | Full sweep at 20 starts; checkpoints to `isoloudness_starts20.csv` and resumes |
| `confirm_vent_floor.R` | not run | Reproducible example for the GitHub issue |

Scripts 2–6 and the 20-start rebuild operate on an in-memory copy of
`R/open_nl.R` created with `sys.source()` into an environment whose parent is
the package namespace, so the installed function is untouched. Each verifies
its insertion anchors and aborts rather than instrumenting blind.

---

## 2. Findings

### 2.1 Settled — no defect

**No multi-start bug.** (Script 2.) Within each optimization branch the running
best objective rises monotonically with the number of starts in every case
tested: A5 relaxed 59.1371 → 59.1907 → 59.2678 at 3/10/20 starts; A4 floor-0
67.2575 → 68.2161; A4 relaxed 71.3210 → 71.9352. The reported SII moves the
other way because SII is not the objective. §2 of the todo list is closed; no
fix required on that account.

**No post-hoc clamping defect.** `gain_array` is built inside `obj_fn` with the
same clamp applied at lines 327–329, so the objective never scored a solution
that could not be delivered.

**The three spectrum pipelines agree.** (Script 3, Part A.)
`normal_speech_loudness()` and the `helpers_jaaa.R` path give identical results
at 50, 65 and 80 dB SPL. Grid range and renormalisation are worth 0.0016 sones
(9.0333 vs 9.0317); passing a precomputed `ref` changes nothing.

### 2.2 Defects found

**`vent_floor` does not prescribe at the requested floor.** (`R/open_nl.R`
381–395 for 65 dB, 404–418 for other levels.) When `vent_floor < 0`,
`open_nl()` runs the whole optimization twice — once with the floor forced to
0 — and returns whichever branch has the higher raw SII from `compute_sii()`.
Consequences:

1. The returned prescription may use a 0 dB floor despite the argument.
2. Any difference between `vent_floor = -10` and `vent_floor = 0` is rectified
   to `max(0, Δ)`. This is what the published audiogram-family figures plot.
3. Branch selection uses raw SII; within-branch selection uses the penalized
   objective. Two criteria in one function.

Confirmed empirically: the first ten per-start values of the A4 floor-−10 run
are identical to the A4 floor-0 run (67.2575 / 67.1778 / 67.0672 / …), so the
nested floor-0 branch is the same computation as the standalone call.

Drafted as `issue_vent_floor.md` (needs its code fence repaired and a stronger
reproducible example — see §5).

**The manuscript's loudness values come from the superseded engine.**
(Script 8, Part A — the most consequential finding of the session.) The
manuscript states normal-hearing speech loudness as 1.21 / 6.81 / 20.52 sones
at 50 / 65 / 80 dB SPL. Running the same dense spectra through the superseded
`calculate_loudness_cpp` (the older `bramslow2004` port, still exported)
returns **1.2072 / 6.8087 / 20.5242** — an exact match to the printed
precision. AUDMOD returns 3.1577 / 9.0333 / 22.3887.

So Table 1's budget decomposition, the 7.00 sone ceiling quoted throughout
Results and Discussion, the "74% of capacity" figure, and presumably the L₀
column all sit on the old engine, while every analysis run in this session used
AUDMOD. The engines differ by 2.6× at 50 dB and 1.33× at 65 dB. These are
different models, not a port discrepancy — which is why they can disagree by
33% while the port agrees with AMT to 6e-15. **Every sone figure in the
manuscript needs regenerating on AUDMOD.**

**The optimizer's RNG seed is set inside the function.** Line 295,
`set.seed(as.integer(sum(threshold) * 100 + eval_level))`. This clobbers the
caller's stream and makes seed-based precision estimates impossible — five
seeds return bit-identical results. It also means the −10 dB and 0 dB runs at a
given level draw identical starting points.

**`options()` leakage.** `cap_rule_comparison.R` set `open_nl_maxit = 150` and
`open_nl_starts = 1` globally without restoring, so any script sourced after it
in the same session inherited both. Patched (§5).

### 2.3 Findings that change the manuscript

**The objective is not SII, and the anchor term dominates roughness.**
(Script 2.) `score` is SII × 100. In all nine solutions examined
`anchor_penalty` (2.77–4.32) exceeded `roughness_penalty` (0.55–1.86). The
anchor is `sum(abs(shifts)) * 0.1` (line 268) — an L1 shrinkage toward the
Open-NL heuristic prescription, worth roughly 0.03 in SII units at A5.
Solutions are not SII-optimal; they are shrunk toward the heuristic, by an
amount that depends on `open_nl_starts`.

**The loudness cap binds almost everywhere in the family sweep.** (Script 4,
Part F.) At the budget caps actually used (L0 + 0.5/1/2/3), 28 of 32 cells sit
at the cap to four decimals. An earlier run showing slack used the package
default cap of 9.033 — normal-hearing loudness, identical for every listener —
not the budget. The loudness budget is the active constraint, which supports
the reframing. Note this 28-of-32 figure applies to the family sweep only, NOT
to the canonical-profile decomposition in Table 1, where most profiles have
substantial slack (A4 at cap; A5 0.27–0.44 spare; A1 and A3 about 2.0).

**The corrected contrast is iso-loudness.** (Script 5.) With the double-run
disabled, 58 of 64 cells have `|d_sones| ≤ 1e-4`, so `d_SII` is a like-for-like
efficiency difference at matched loudness. Six cells are not — e1500_s50 b3
(+0.343), e2000_s50 b3 (+0.485), e3000_s50 b3 (−0.242), e2000_s40 b3 (−0.131),
e2000_s30 b1 (+0.110), e1000_s40 b1 (−0.085) — five of them at budget 3 where
the cap stops binding. Flag or exclude.

This is a stronger claim than the original: matched loudness, more audibility.
It also pre-empts the criticism that Table 3 compared Open-NL against NAL-NL2
at unequal loudness.

**The rebuild reproduces the published figures where they are positive**
(e1000_s20 b0.5: +0.0547 vs 0.055; e3000_s20 b1.0: +0.0198 vs 0.020) and shows
negative values where the figures showed 0.000, confirming the rectification
end to end.

**Three starts under-converges the floor-0 side.** (Script 6.) A negative
`d_SII` at iso-loudness is impossible for a real feasibility comparison, so
every negative cell is artefact. Probing six such cells at 3 / 10 / 20 restarts,
five collapsed — and they collapsed from the floor-0 side, where SII0 had been
overstated. Examples: e3000_s20 b0.5 SII0 falls 0.9642 → 0.9398 while SII−10
barely moves; e1500_s20 b1.0 SII0 0.8980 → 0.8935 with SII−10 constant.

Revised negatives at 20 starts: −0.0002, −0.0001, −0.0052, with three turned
positive. **The noise floor is about ±0.005, not the ±0.02 estimated from the
3-start data.** Revised verdicts at budget 0.5:

| Edge (Hz) | d_SII range at budget 0.5 (3 starts) | Verdict at ±0.005 |
|---|---|---|
| 1000 | +0.037 to +0.082 | real |
| 1500 | +0.014 to +0.035 | real |
| 2000 | +0.007 to +0.015 | real |
| 3000 | −0.003 to +0.003 | null (but see below) |

Only edge 3000 remains within noise, and even there e3000_s20 b0.5 reads
+0.0223 at 20 starts, so that null may itself be a 3-start artefact. The full
20-start sweep will settle it.

**Effect magnitudes are restart-dependent.** The two control cells drift
downward with more restarts: e1000_s30 b0.5 goes 0.0823 → 0.0787 → 0.0693;
e1000_s20 b0.5 goes 0.0547 → 0.0456 → 0.0489. Real effects, but roughly 15%
smaller at 20 starts, because better convergence lets the anchor penalty pull
harder. No effect size can be quoted without naming the restart count.

**SII is non-monotone in budget** in 28 of 32 series at 3 starts. Loosening the
constraint can lower the reported SII, which is impossible for a feasibility
frontier — the tighter budget's solution remains feasible. Same cause. Either
take the running best across budgets or frame the curve explicitly as the
behaviour of a penalized optimizer. Recheck at 20 starts.

**The mechanism is redistribution toward the region just above the audible
edge.** At e1000_s30 b0.5 the floor-−10 solution moves +10.8 dB at 2 kHz,
+11.1 at 4 kHz and −7.9 at 8 kHz, with negative gain at 500 and 1000 Hz. Budget
is drawn from both ends of the spectrum. This is a better figure than the
heatmap and a testable prediction. Note it also contradicts the manuscript's
claim (line 75) that the floor "acts exclusively as a ceiling on low-frequency
attenuation": 8 kHz gain falls by up to 18 dB when the floor is relaxed.

**The cap has no empirical anchor.** (Script 8, Part C.) NAL-NL2-aided loudness
as a fraction of the normative cap across A1–A5: 0.458, 0.388, 0.402, 0.726,
0.609. No consistent fraction, so no established rationale supplies a target
loudness to anchor L_cap. The cap is a modelling choice, and the continuous cap
axis in the feasibility maps is the right way to present it — this converts a
weak assumption into a justified design decision. (A7 at 1.752 is expected
given the air-bone gap; A6 and A7 have L0 = 0, so "budget above unaided"
degenerates to an absolute cap for them.)

### 2.4 Loudness engine characterization

**Growth is mildly compressive.** (Script 3, B2.) 1 kHz tone, normal hearing:
ratios settle at 1.75–1.91 per 10 dB rather than 2.0. Report as
characterization, not failure.

**Zero below threshold, correctly.** (B3.) Normal hearing silent to +5 dB SPL;
A5 silent at 4 kHz up to 60 dB SPL against an 80 dB HL.

**Recruitment present and ordered by threshold.** (B4 + Script 4, Part E.)
Growth steepens with loss; the apparent non-monotonicity across profiles is
configuration, not severity — A2 is reverse-slope with 20 dB HL at 4 kHz.

**The 1-sone anchor cannot be tested through the R wrapper, and the earlier
failure was an artefact.** (Script 7.) `calculate_loudness_audmod()`
interpolates the input spectrum **linearly in dB** across a log-frequency grid
before building `PowSpect`. A single-bin spike is therefore averaged against
−200 dB neighbours, and the result depends entirely on where the FFT bin centre
falls: 0.3161 at 10 Hz spacing, 0.0000 at exactly one grid point per FFT bin,
0.9152 at 0.5 Hz spacing. Every Part 2 and Part 3 zero in that log is this
artefact, not the model. A 1-ERB band of equal power gives 0.486 where the tone
gives 0.000 at the same spacing.

The trend points toward 1.0 as the spike widens, so the absolute scale is
plausibly correct — but it is untested. Testing it properly means bypassing the
wrapper: build `PowSpect` directly as a length-4096 vector on `j * fs/N`, zero
except bin 256 (1000 Hz exactly), and call `audmod_loudness_cpp()` with a `ref`
from `audmod_reference_cpp()`. Low priority: nothing in the paper depends on
tonal loudness.

**The smooth-spectrum control never moved** — 9.0333 sones at every input grid
spacing tested — so the production path is unaffected by any of this.

**Monaural vs binaural is unresolved.** `calculate_binaural_loudness()` expects
a structured object, not a scalar, so Script 8 Part B errored. AUDMOD is called
with `Binaural = 0`, so 9.0333 is monaural. With `alpha_b = -0.25` the implied
summation factor is about 2^0.75 ≈ 1.68, giving roughly 15.2 sones binaural —
not the factor of 2 that would give 18. Worth confirming against the literature
before any binaural claim.

---

## 3. Manuscript consequences

1. **Regenerate every sone value on AUDMOD.** Table 1, the 7.00 sone ceiling,
   the 74%-of-capacity figure, and the L₀ column all come from the superseded
   engine. The 65 dB ceiling becomes about 9.03 rather than 6.81/7.00.
2. **Disclose the rectification.** `vent_floor = -10` returned the better of two
   branches, so the published statistic was max(0, Δ); the revision optimizes
   each floor once and reports SII at each floor with achieved loudness.
3. **Recompute the main result as an iso-loudness comparison**, excluding or
   flagging the non-iso-loudness cells.
4. **Justify the cap as a modelling choice**, citing the NAL-NL2 scatter
   (0.39–0.73 of the cap, no consistent fraction) and pointing to the
   continuous cap axis as the sensitivity analysis.
5. **Report the optimizer resolution limit** (~0.005 SII at 20 restarts) in
   Methods, derived from negative-cell excursions, since seed-based estimation
   is impossible.
6. **Name the restart count with every effect size** — magnitudes are about 15%
   smaller at 20 starts than at 3.
7. Address budget non-monotonicity explicitly.
8. Correct line 75: the floor does not act exclusively on low frequencies.
9. Strengthen the limitation on AUDMOD's unverified absolute loudness scale.

### Done on `manuscript-audit-edits`

- Solutions described as penalized-optimal, with the nine-term objective stated
  in Methods (commits `acf8f8d`, `d32f412`, `e1e86ab`).
- `open_nl_starts` and deterministic-seed behaviour documented (`b854972`) —
  **the stated value of 3 must change when the 20-start numbers land**.
- L_cap definition clarified and the misplaced 28-of-32 claim removed
  (`22fbc3b`, `330fbc5`, `852f0b9`); duplicated clauses repaired (`8a7f819`).
- Validation section rewritten around port fidelity / input path /
  reference-free behaviour; orphaned Bland-Altman figure removed and figures
  renumbered (`3740568`, `6bd7db1`, `83c8d78`).

---

## 4. Analyses still to run

1. `rebuild_isoloudness_20.R` — running. Full family at 20 starts.
2. The other three SII variants. `gen_audiogram_family.R` computes
   `diff_complete_s`, `diff_complete_full` and `diff_ansi` alongside
   `diff_smoothed_s`; all four are rectified and need the same rebuild.
3. Desensitization scales 0 and 0.5 — the figures have three panels; the
   rebuild covers only ds = 1.
4. Table 1 regenerated on AUDMOD.
5. Feasibility maps at 20 starts — the 21.3 vs 29.9 dB figures quoted in the
   Discussion sit on a floor-0 contour that 3 starts demonstrably
   under-converges. Largest job (357 grid points per profile); decide after the
   sweep lands.

---

## 5. Repository actions outstanding

- [ ] **Revert `helpers_jaaa.R`.** Gemini wrapped its `options(open_nl_maxit =
      800)` in `.old <-` / `on.exit(options(.old))`. Verified: the restore fires
      when `source()` returns, so the setting is undone before any caller uses
      it. Scripts fall through to the package default at line 319 — the same
      value, so no result changed, but the setting is decorative. Keep the
      `options()` call, delete the two added lines.
- [ ] **Fix the logging default.** The line Gemini inserted into 22 scripts
      prints `getOption("open_nl_maxit", 500)`, but `open_nl.R` line 319 uses
      `800`.
- [ ] **Check `issue_vent_floor.md` raw bytes** — `grep -c '^```'` should return
      2, and `EOF` must not appear. Replace the reproducible example with the
      verified case from `confirm_vent_floor.R`. Note that ties go to the
      constrained branch (`sii_c >= sii_r`).
- [ ] **`generate_remaining_tables.R` vs `gen_multi_level_tables.R`**: neither
      passes `vent_floor`, so both inherit the `-10` default and went through
      the double-run. The former also sets `enable_severe_booster = TRUE` and
      `booster_onset = 60` against defaults of `FALSE` and `70`.
- [ ] **Confirm the cap definition in `gen_audiogram_family.R`** — the rebuild
      assumes L0 is that listener's unaided loudness and the cap is L0 + budget.
- [ ] Commit `reproducibility_scripts/audit/`, `output/isoloudness/`,
      `issue_vent_floor.md` and this register.
- [x] Archived stale drafts: `JAAA_manuscript_new.md` (Sep 17) and
      `gen_audiogram_family_new.R` (Sep 17). Both were older than the tracked
      versions despite their names. Untracked, so git gave no warning.

The `options()` restores in `cap_rule_comparison.R`,
`generate_lhs_sensitivity.R`, `generate_lhs_sensitivity_safe.R` and
`validate_booster_ablation.R` are correct as patched. Note that `on.exit()`
only fires under `source()` — RStudio's Run button does not trigger it.

---

## 6. Deprioritised

- End-to-end Bland-Altman against AMT. Stage-by-stage agreement to 6e-15 across
  23 cases establishes the port; the end-to-end test would mostly validate the
  spectral input path, and Script 3 Part A has now done that directly.
- Roughness weight sensitivity sweep. The anchor term is the dominant one.
- The 1-sone absolute anchor, until tested at native FFT resolution.
