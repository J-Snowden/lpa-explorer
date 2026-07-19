# Latent Profile Explorer

**[Live demo](https://j-snowden.github.io/lpa-explorer/)**

An interactive demonstration of a latent profile analysis (LPA) on employee-experience
survey data. **The data are synthetic**, generated from a fully specified measurement
model in [`01_simulate.R`](01_simulate.R); no real responses are involved. The generating
parameters were chosen to produce a recoverable structure — anyone competent will assume
as much, and saying it plainly costs nothing. The point of the demo is not the profiles
themselves but the decision *how many* to retain, and what the conventional selection
criteria do and do not settle. The static viewer in [`index.html`](index.html) reads a
single precomputed file, `data/model_results.json`; all fitting happens offline.

## Measurement model

Five constructs — Clarity, Enablement, Engagement, Impact, Autonomy — measured by 15 items
on a 4-point scale, with two theoretically motivated cross-loadings (item i1 on Clarity and
Enablement; item i7 on Engagement and Autonomy). Responses come from a four-profile latent
mixture on an ordinal engagement gradient, with 3% MCAR missingness so FIML has work to do.
Simulating at the item level, not the factor-score level, lets the full pipeline run exactly
as it would on real responses.

## Analytic sequence

1. **Split-sample EFA / CFA** (50/50). Suitability on the EFA half: KMO = .874, Bartlett's
   test significant; parallel analysis extracts five factors.
2. **CFA on the held-out half**, comparing a cross-loading specification against a
   constrained one by scaled χ² difference (MLR, FIML). The cross-loading model is retained
   — CFI = .997, TLI = .996, RMSEA = .011 [.000, .025], SRMR = .021 — a decisive improvement
   over the constrained model (CFI = .959).
3. **Factor scores** extracted from the winning model refit on the full sample
   (`lavPredict`, regression method).
4. **An 18-model LPA grid** — three covariance structures × k = 1–6 — scored on BIC,
   entropy, the bootstrap likelihood-ratio test (BLRT), and minimum class size.

## Selection

The retained solution is **Model 2 (varying variances, zero covariances), k = 4**
(entropy .854; smallest class 17.7%; all four AvePP ≥ .90). The honest part is what the
criteria contribute. BIC has **no minimum at k = 4** — it declines monotonically through
k = 6 — so the elbow is the operative rule: the BIC improvement retains 36% of the previous
step at k = 4 but only 19% at k = 5. **BLRT is significant at every k** (p = .0099, the
floor for 100 draws) and adjudicates nothing. **Minimum class size never binds** — every
Model-2 solution clears 5% through k = 6. Two of the four conventional criteria are silent;
the decision rests on the BIC elbow, declining entropy, and interpretability (Nylund,
Asparouhov, & Muthén, 2007; Spurk et al., 2020; Celeux & Soromenho, 1996; Masyn, 2013).

## Recovery

Against known membership the solution recovers **72.8%**, and every misclassification falls
into an *adjacent* profile — the expected failure mode for an ordinal gradient rather than
categorical confusion. Estimated class sizes (19.0 / 31.6 / 31.6 / 17.7) drift from the
realized generating proportions (15.8 / 36.9 / 34.9 / 12.4): the model over-populates the
extremes, ordinary boundary behaviour in finite mixtures.

## A tension the simulation exposes

Entropy and factor distinctness trade off directly here. Tightening the profiles to improve
class separation pushes the affective factors toward collinearity (Engagement–Autonomy
r = .89), which degrades the factor structure; loosening them restores the structure but
blurs the profiles. Five theorized dimensions carry closer to three dimensions of
independent information. This is a real property of experience data, not an artifact of the
simulation.

Regression-method factor scores were used throughout. Bartlett scoring is the alternative —
it produces unbiased scores, but in related work failed to reach adequate entropy across all
18 specifications, so regression scoring was retained.

## Conventional segmentation vs. profiles

The final script also computes the comparison the viewer is built around. Organizational
attributes — department, tenure, level — are drawn independently of profile membership in the
simulation, mirroring the source study's finding that experience profiles cut across every
demographic characteristic examined. The exported `segmentation` block quantifies it: the
widest gap any conventional cut produces between two segments (≈ 0.19 SD) against the widest
gap the four-profile solution produces (≈ 2.48 SD, an order of magnitude larger), together
with the Holm-corrected chi-square tests (all null, Cramér's V ≤ .07) and the within-segment
profile composition. The point is that no segmentation the HRIS already supports would surface
the ~19% in the lowest-experience profile — they are spread evenly across every group.

## Provenance and attribution

The method was applied to real assessment-experience data in peer-reviewed work presented at
AERA 2026:

> Herrmann Abell, C. F., Deverel-Rico, C., Snowden, J., Brubaker, A., Campanella, M.,
> Flanagan, J., Lee, D., Olson, P., & Wilson, C. D. (2026). *Centering Student Voice in
> Science Assessment through Leveraging Student Experience Data.* AERA Annual Meeting,
> Los Angeles.

Herrmann Abell, Deverel-Rico, and Snowden are co-equal first authors. This author (Snowden)
contributed the factor analysis, the latent profile analysis, and the model selection. The
data in this repository are **synthetic** and generated from stipulated parameters; they are a
reconstruction of the method, not the study's findings. The real responses belong to the
research organization and were collected from minors under IRB protocols, and are not
distributed here.

## Reproducing

Run the three scripts in order, from the project root:

```r
source("01_simulate.R")     # writes data/synthetic_responses.csv + generating_parameters.rds
source("02_fit_models.R")   # EFA/CFA/LPA; writes data/fitted_objects.rds
source("03_export_json.R")  # writes data/model_results.json
```

Then serve `index.html` over HTTP (it fetches the JSON, so `file://` will not work — any
static server, or GitHub Pages, suffices). Requires `lavaan`, `tidyLPA`, `psych`, `dplyr`,
`tidyr`, `stringr`, and `jsonlite`.
