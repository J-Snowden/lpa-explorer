# ==============================================================================
# EMPLOYEE EXPERIENCE SURVEY — SYNTHETIC DATA GENERATION
# ==============================================================================
# Generates item-level responses from a fully specified measurement model plus
# a four-profile latent mixture. Nothing here derives from any real dataset;
# all parameters are stipulated below and the data are drawn from them.
#
# The point of simulating at the ITEM level rather than the factor-score level
# is that the full pipeline (EFA -> CFA -> factor scores -> LPA) then runs on
# these data exactly as it would on real responses. If we generated factor
# scores directly we would be skipping the measurement half of the argument.
#
# Output: data/synthetic_responses.csv  (one row per respondent)
# ==============================================================================

library(dplyr)
library(tidyr)

set.seed(20260718)

N <- 1400

# ------------------------------------------------------------------------------
# TUNING CONSTANTS
# ------------------------------------------------------------------------------
# Per-factor multipliers on the within-profile standard deviations. These are
# per-factor rather than global for a structural reason: within a profile the
# factors are independent, so ALL of the between-factor correlation comes from
# the mixture. A single global scale therefore controls two things at once --
# how correlated the factors are, and how separated the profiles are -- and
# they pull in opposite directions:
#
#   Low  scale -> tight profiles (good LPA) but factors correlated ~.7, which
#                 collapses the EFA; parallel analysis under-extracts.
#   High scale -> factors decorrelate (good EFA) but profiles blur and BIC
#                 descends with no elbow.
#
# Splitting the multiplier resolves it. Clarity and Enablement get LARGE
# within-profile spread: individuals vary a lot on them, but that variation is
# mostly unrelated to profile membership. Engagement, Impact and Autonomy stay
# tight, so profile separation is driven by the affective dimensions.
#
# This is the fanning effect stated precisely, and it is the substantive claim
# the demo is built on: role clarity varies between people without predicting
# which experience profile they fall into; felt meaning predicts it strongly.
#
# Validated by simulation: mean inter-factor r = .40, BIC minimum at k = 4,
# entropy ~.84, smallest class ~12%.
#
#   Entropy below .80        -> LOWER the affective multipliers (3rd/4th/5th)
#   Parallel analysis  < 5   -> RAISE the structural multipliers (1st/2nd)
#                        names:  Clarity Enablement Engagement Impact Autonomy
SD_MULT <- c(1.80, 1.80, 0.65, 1.10, 0.70)

# ------------------------------------------------------------------------------
# Measurement model
# ------------------------------------------------------------------------------
# Five constructs. Two deliberate cross-loadings are specified (items 1 and 7),
# mirroring the situation where an item's content plausibly spans two
# constructs. These exist so the CFA in 02_fit_models.R has something real to
# detect when it compares a cross-loading model against a constrained one.

FACTORS <- c("Clarity", "Enablement", "Engagement", "Impact", "Autonomy")

# item -> named vector of standardized loadings
loadings <- list(
  i1  = c(Clarity = .55, Enablement = .35),   # cross-loading
  i2  = c(Clarity = .66),
  i3  = c(Enablement = .80),
  i4  = c(Enablement = .64),
  i5  = c(Engagement = .82),
  i6  = c(Engagement = .85),
  i7  = c(Engagement = .46, Autonomy = .32),  # cross-loading
  i8  = c(Autonomy = .64),
  i9  = c(Impact = .68),
  i10 = c(Impact = .73),
  i11 = c(Autonomy = .63),
  i12 = c(Autonomy = .82),
  i13 = c(Autonomy = .79),
  i14 = c(Clarity = .71),                     # 3rd indicator: two-indicator
  i15 = c(Impact = .70)                       # factors are weakly identified
)

# Item wordings, for the codebook export and the UI
item_text <- c(
  i1  = "I understand what is expected of me in my role.",
  i2  = "Something about how work is organized makes it hard to do my best. (R)",
  i3  = "I can draw on skills and experience I already have to do this work.",
  i4  = "The training and onboarding I received prepared me for this work.",
  i5  = "I want to learn more about the area my work touches.",
  i6  = "I find the substance of my work interesting.",
  i7  = "I want to tell people outside work about what I am working on.",
  i8  = "The work I do connects to things I care about personally.",
  i9  = "My work relates to a problem that matters beyond this company.",
  i10 = "If my team's work were better understood, the wider org would benefit.",
  i11 = "This work has changed how I think about the problem space.",
  i12 = "I can apply what I am learning here to where I want to go next.",
  i13 = "I can use what I have learned here to help other people.",
  i14 = "It is clear to me how my work is evaluated.",
  i15 = "The problems my team works on are worth solving."
)

# ------------------------------------------------------------------------------
# Profile structure
# ------------------------------------------------------------------------------
# Four profiles on an ordinal gradient. The substantive pattern being built in
# is the FANNING effect: profiles sit close together on the structural factors
# (Clarity, Enablement) and spread apart on the affective ones (Engagement,
# Impact, Autonomy). This is the finding the demo is about, so it is specified
# here and left to emerge from estimation rather than asserted in the UI.

profile_labels <- c("Low Engagement", "Moderate-Low Engagement",
                    "Moderate-High Engagement", "High Engagement")

profile_props <- c(.14, .36, .38, .12)

# rows = profiles (ascending), cols = FACTORS
profile_means <- matrix(c(
  -0.75, -0.70, -1.35, -1.05, -1.20,
  -0.25, -0.22, -0.45, -0.35, -0.40,
   0.25,  0.24,  0.45,  0.35,  0.40,
   0.70,  0.68,  1.30,  1.00,  1.15
), nrow = 4, byrow = TRUE, dimnames = list(profile_labels, FACTORS))

# Varying variances, zero within-profile covariance (matches the Model 2
# specification: variances = "varying", covariances = "zero")
profile_sds <- matrix(c(
  0.62, 0.60, 0.72, 0.70, 0.68,
  0.55, 0.54, 0.60, 0.58, 0.56,
  0.55, 0.54, 0.58, 0.57, 0.55,
  0.60, 0.58, 0.66, 0.64, 0.62
), nrow = 4, byrow = TRUE, dimnames = list(profile_labels, FACTORS)) *
  matrix(SD_MULT, nrow = 4, ncol = length(FACTORS), byrow = TRUE)

# ------------------------------------------------------------------------------
# Response thresholds
# ------------------------------------------------------------------------------
# Cut points on the standardized latent response variate, producing a 4-point
# scale skewed toward agreement -- the usual shape for experience items, where
# a symmetric distribution would be the surprising result.
THRESHOLDS <- c(-1.10, -0.30, 0.50)

MISSING_RATE <- 0.03   # item-level MCAR missingness, so FIML has work to do

# ==============================================================================
# GENERATE
# ==============================================================================

# --- 1. Profile membership ----------------------------------------------------
class_idx <- sample(seq_len(4), size = N, replace = TRUE, prob = profile_props)

# --- 2. Latent factor scores --------------------------------------------------
# Within-profile covariance is zero by specification, so each factor is drawn
# independently. (Deliberately avoids MASS::mvrnorm -- MASS masks dplyr::select,
# which breaks the downstream scripts if both are attached in one session.)
eta <- matrix(NA_real_, nrow = N, ncol = length(FACTORS),
              dimnames = list(NULL, FACTORS))
for (k in seq_len(4)) {
  idx <- which(class_idx == k)
  if (length(idx) == 0) next
  for (f in seq_along(FACTORS)) {
    eta[idx, f] <- rnorm(length(idx),
                         mean = profile_means[k, f],
                         sd   = profile_sds[k, f])
  }
}

# --- 3. Item responses --------------------------------------------------------
items <- matrix(NA_integer_, nrow = N, ncol = length(loadings),
                dimnames = list(NULL, names(loadings)))

for (j in seq_along(loadings)) {
  spec       <- loadings[[j]]
  communality <- sum(spec^2)
  resid_sd    <- sqrt(max(1 - communality, 0.05))

  latent <- rowSums(sapply(names(spec), function(f) spec[[f]] * eta[, f]))
  y      <- latent + rnorm(N, 0, resid_sd)
  y      <- as.numeric(scale(y))

  items[, j] <- findInterval(y, THRESHOLDS) + 1L
}

# --- 4. Missingness -----------------------------------------------------------
miss <- matrix(runif(length(items)) < MISSING_RATE, nrow = nrow(items))
items[miss] <- NA_integer_

# --- 5. Open-text ------------------------------------------------------------
# Response BEHAVIOR is the signal here, not the prose. Skip and dismissal rates
# are profile-dependent, and deliberately inverted between the two prompts:
# on "what worked" the disengaged say least; on "what was hard" they say most,
# because the engaged have nothing to report. Downstream this is the point --
# free-text complaint volume is biased toward the disengaged, so reading a
# comment corpus at face value systematically overweights them.

# Contrasts are set wider than the target output pattern on purpose. Profile
# assignment recovers at roughly 73%, and misclassification blends adjacent
# profiles together, which attenuates any specified gradient. Widening here
# means the inversion still reads clearly after that attenuation.
skip_oe1     <- c(.030, .015, .008, .004)   # by profile, ascending
dismiss_oe1  <- c(.220, .100, .045, .025)
skip_oe2     <- c(.100, .170, .230, .300)   # inverted
dismiss_oe2  <- c(.070, .130, .180, .270)

pool_oe1_pos <- c(
  "The examples actually matched the kind of work I do day to day.",
  "It was clear what each question was getting at.",
  "I liked that it asked about things nobody usually asks about.",
  "Short enough that I could give real answers instead of rushing."
)
pool_oe1_neg <- c(
  "Not much.", "It was fine I guess.", "It was short."
)
pool_oe2_sub <- c(
  "Some of the wording was ambiguous -- 'my team' could mean two different things.",
  "Hard to answer about onboarding when mine was two years ago.",
  "There was no option to say a question did not apply to me."
)
pool_oe2_surf <- c(
  "Too long.", "The scale was confusing.", "Font was small."
)
dismissals <- c("nothing", "n/a", "no", "none", "idk", "not really")

draw <- function(k, skip_p, dismiss_p, pool_main, pool_alt, alt_weight) {
  r <- runif(1)
  if (r < skip_p[k])                    return(NA_character_)
  if (r < skip_p[k] + dismiss_p[k])     return(sample(dismissals, 1))
  if (runif(1) < alt_weight[k])         return(sample(pool_alt, 1))
  sample(pool_main, 1)
}

oe1 <- vapply(class_idx, function(k)
  draw(k, skip_oe1, dismiss_oe1, pool_oe1_pos, pool_oe1_neg,
       alt_weight = c(.70, .40, .12, .03)),
  character(1))

oe2 <- vapply(class_idx, function(k)
  draw(k, skip_oe2, dismiss_oe2, pool_oe2_sub, pool_oe2_surf,
       alt_weight = c(.75, .40, .18, .06)),
  character(1))

# --- 5b. Organizational attributes -------------------------------------------
# Drawn INDEPENDENTLY of profile membership -- deliberately, and this is the
# substantive claim of the whole demo rather than a modelling convenience.
#
# Employee listening programs segment by what the HRIS provides: department,
# tenure, level. If experience profiles cut across those categories, then no
# conventional segmentation recovers them, and the 19% having the worst
# experience stay invisible in every dashboard the org already has. The only
# route to them is the survey itself, analyzed person-centered.
#
# This mirrors the finding in the source research, where profile membership
# showed no significant association with any demographic characteristic
# examined (Cramer's V .049-.091, all null after Holm correction).

departments <- c("Engineering", "Product", "Content", "Data & Analytics",
                 "Marketing", "Operations")
dept_probs  <- c(.28, .12, .22, .10, .14, .14)

tenure_bands <- c("Under 1 year", "1-3 years", "3-5 years", "5+ years")
tenure_probs <- c(.22, .34, .26, .18)

levels_ic <- c("Individual contributor", "Senior IC", "Manager")
level_probs <- c(.44, .38, .18)

org <- data.frame(
  department = sample(departments,  N, replace = TRUE, prob = dept_probs),
  tenure     = factor(sample(tenure_bands, N, replace = TRUE, prob = tenure_probs),
                      levels = tenure_bands),
  level      = factor(sample(levels_ic, N, replace = TRUE, prob = level_probs),
                      levels = levels_ic),
  stringsAsFactors = FALSE
)

# --- 6. Assemble --------------------------------------------------------------
synthetic <- as_tibble(items) %>%
  mutate(
    respondent_id = sprintf("R%04d", seq_len(N)),
    true_profile  = factor(profile_labels[class_idx], levels = profile_labels),
    department    = org$department,
    tenure        = org$tenure,
    level         = org$level,
    oe_worked     = oe1,
    oe_hard       = oe2,
    .before = 1
  )

dir.create("data", showWarnings = FALSE)
write.csv(synthetic, "data/synthetic_responses.csv", row.names = FALSE)

saveRDS(
  list(
    factors        = FACTORS,
    loadings       = loadings,
    item_text      = item_text,
    profile_labels = profile_labels,
    profile_props  = profile_props,
    profile_means  = profile_means,
    profile_sds    = profile_sds,
    thresholds     = THRESHOLDS,
    sd_mult        = SD_MULT,
    n              = N,
    departments    = departments,
    tenure_bands   = tenure_bands,
    levels_ic      = levels_ic,
    seed           = 20260718
  ),
  "data/generating_parameters.rds"
)

# ------------------------------------------------------------------------------
# Sanity checks
# ------------------------------------------------------------------------------
# true_profile is retained in the CSV only for these checks and for the
# recovery diagnostic in 02_fit_models.R. It must never be passed to the LPA.

message("--- Item means (expect ~2.7-2.9 on a 1-4 scale) ---")
print(round(colMeans(items, na.rm = TRUE), 2))

message("--- Organizational attributes (independent of profile by design) ---")
message("Association of profile with department, p = ",
        round(chisq.test(table(org$department, class_idx))$p.value, 3),
        " (expected: non-significant)")

message("--- True profile sizes ---")
print(table(synthetic$true_profile))

message("--- Latent factor means by profile (fanning check) ---")
fan <- aggregate(eta, by = list(profile = profile_labels[class_idx]), FUN = mean)
fan$profile <- factor(fan$profile, levels = profile_labels)
print(fan[order(fan$profile), ], row.names = FALSE, digits = 2)

message("\nIf item means sit outside 2.5-3.1, adjust THRESHOLDS.")
message("If the profile means above are not clearly ordered, lower the")
message("affective multipliers (positions 3-5) in SD_MULT.")
