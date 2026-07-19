# Latent Profile Explorer

**[Live demo](https://j-snowden.github.io/lpa-explorer/)**

An interactive demonstration of latent profile analysis (LPA) using synthetic
employee-experience survey data. **The data are synthetic** and were generated from a
fully specified measurement model in [`01_simulate.R`](01_simulate.R); no real responses
are involved. The parameters were chosen to produce a recoverable four-profile structure.
The demonstration focuses on the decision of how many profiles to retain and what the
conventional selection criteria contribute to that decision. The static viewer in
[`index.html`](index.html) reads a single precomputed file,
`data/model_results.json`; all model fitting happens offline.

## Measurement model

The model includes five constructs: Clarity, Enablement, Engagement, Impact, and
Autonomy. They are measured by 15 items on a 4-point scale, with two theoretically
motivated cross-loadings (item i1 on Clarity and Enablement; item i7 on Engagement and
Autonomy). Responses are generated from a four-profile latent mixture ordered along an
engagement gradient. Three percent of item responses are missing completely at random,
allowing the pipeline to use full information maximum likelihood (FIML). Simulating at
the item level allows the full measurement and profile-analysis pipeline to run as it
would with observed responses.

## Analytic sequence

1. **Split-sample EFA and CFA** (50/50). On the EFA half, KMO = .874, Bartlett's test is
   significant, and parallel analysis supports a five-factor solution.
2. **CFA on the held-out half**, comparing a cross-loading specification with a
   constrained model using a scaled χ² difference test (MLR, FIML). The cross-loading
   model is retained (CFI = .997, TLI = .996, RMSEA = .011 [.000, .025], SRMR = .021)
   and fits substantially better than the constrained model (CFI = .959).
3. **Factor scores** extracted from the selected model refit on the full sample
   (`lavPredict`, regression method).
4. **An 18-model LPA grid** consisting of three covariance structures across k = 1 to 6,
   evaluated using BIC, entropy, the bootstrap likelihood-ratio test (BLRT), and minimum
   class size.

## Selection

The retained solution is **Model 2 (varying variances, zero covariances), k = 4**
(entropy .854; smallest class 17.7%; all four AvePP ≥ .90). Each selection criterion
contributes different information. BIC continues to decline through k = 6, so the
absolute minimum does not identify k = 4. The decision instead uses the elbow: the BIC
improvement at k = 4 retains 36% of the previous step, compared with 19% at k = 5.
Entropy supports adequate classification at k = 4 and declines as k increases. The BLRT
is significant at every value of k (p = .0099, the minimum possible with 100 bootstrap
draws), so it does not distinguish among the solutions. Every Model 2 solution through
k = 6 has a minimum class larger than 5%, meaning minimum class size does not rule out
any solution. Taken together, the BIC elbow, classification quality, class sizes, and
interpretability support retaining four profiles (Nylund, Asparouhov, & Muthén, 2007;
Spurk et al., 2020; Celeux & Soromenho, 1996; Masyn, 2013).

## Recovery

Compared with known generating membership, the retained solution correctly classifies
**72.8%** of respondents. Every misclassification falls into an *adjacent* profile,
which is consistent with profiles arranged along an ordinal gradient. Estimated class
sizes (19.0 / 31.6 / 31.6 / 17.7) differ from the realized generating proportions
(15.8 / 36.9 / 34.9 / 12.4), with the model assigning larger shares to the two extreme
profiles.

## A tradeoff in the simulation

The simulation illustrates a tradeoff between entropy and factor distinctness. Tightening
the profiles to improve class separation pushes the affective factors toward collinearity
(Engagement–Autonomy r = .89), which weakens the factor structure. Loosening the profiles
strengthens the factor structure but reduces separation among the profiles. In these
generated data, the five theorized dimensions contain closer to three dimensions of
independent information.

Regression-method factor scores were used throughout. Bartlett scoring was also examined,
but in related modeling for this project it did not produce adequate entropy across the
18 specifications. Regression scoring was therefore retained.

## Conventional segmentation and profiles

The final script compares the profile solution with groupings based on department, tenure,
and level. These attributes are generated independently of profile membership, reflecting
the source study's finding that experience profiles cut across the demographic
characteristics examined. The exported `segmentation` block reports the widest gap
produced by a conventional grouping (approximately 0.19 SD) and the widest gap produced
by the four-profile solution (approximately 2.48 SD). It also includes Holm-corrected
chi-square tests (all nonsignificant, Cramér's V ≤ .07) and the profile composition within
each recorded group. In the synthetic data, the Low Engagement profile cuts across these
attributes and therefore does not appear as a separate group in standard summaries.

## Open-text response behavior

The viewer also compares response behavior across profiles for two open-text prompts.
Skip rates for the “what was hard” prompt increase with engagement, meaning respondents
reporting fewer problems are less likely to answer. Responses to the “what worked” prompt
show a different pattern: respondents in the Low Engagement profile usually answer but
are more likely to provide a dismissal. These patterns demonstrate why open-text comments
should not automatically be treated as representative of the full sample.

For this project, a dismissal is a non-skipped response that, after conversion to lowercase
and removal of trailing punctuation, matches one of the fixed non-substantive responses
defined in [`02_fit_models.R`](02_fit_models.R).

## Provenance and attribution

The method was applied to assessment-experience data in a study presented at AERA 2026:

> Herrmann Abell, C. F., Deverel-Rico, C., Snowden, J., Brubaker, A., Campanella, M.,
> Flanagan, J., Lee, D., Olson, P., & Wilson, C. D. (2026). *Centering Student Voice in
> Science Assessment through Leveraging Student Experience Data.* AERA Annual Meeting,
> Los Angeles.

Herrmann Abell, Deverel-Rico, and Snowden are co-equal first authors. Snowden contributed
the factor analysis, latent profile analysis, and model selection. The data in this
repository are **synthetic** and generated from specified parameters. They demonstrate the
method rather than reproduce the study's findings. The original responses belong to the
research organization, were collected from minors under IRB-approved protocols, and are
not distributed here.

## Reproducing

Run the three scripts in order from the project root:

```r
source("01_simulate.R")     # writes data/synthetic_responses.csv + generating_parameters.rds
source("02_fit_models.R")   # EFA/CFA/LPA; writes data/fitted_objects.rds
source("03_export_json.R")  # writes data/model_results.json
```

Then serve `index.html` over HTTP. It fetches the JSON, so `file://` will not work. Any
static server, including GitHub Pages, is sufficient. The analysis requires `lavaan`,
`tidyLPA`, `psych`, `dplyr`, `tidyr`, `stringr`, and `jsonlite`.
