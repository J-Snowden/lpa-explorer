# ==============================================================================
# EMPLOYEE EXPERIENCE SURVEY — MEASUREMENT MODEL AND LATENT PROFILE ANALYSIS
# ==============================================================================
# Runs on the synthetic data produced by 01_simulate.R. The sequence mirrors
# what would be done with real responses: establish the factor structure on
# held-out data, extract scores, then look for subgroups.
#
# Output: fitted objects and tables in memory, plus data/fitted_objects.rds
#         for 03_export_json.R. All tables print to console.
# ==============================================================================

library(dplyr)
library(tidyr)
library(psych)
library(lavaan)
library(tidyLPA)
library(stringr)

# Namespace guards. MASS, stats, and others export functions with these names;
# whichever package was attached last wins, which makes the script's behaviour
# depend on session state. Pin them explicitly.
select <- dplyr::select
filter <- dplyr::filter
mutate <- dplyr::mutate

set.seed(20260718)

FACTORS <- c("Clarity", "Enablement", "Engagement", "Impact", "Autonomy")
ITEMS   <- paste0("i", 1:15)

profile_labels <- c("Low Engagement", "Moderate-Low Engagement",
                    "Moderate-High Engagement", "High Engagement")

raw <- read.csv("data/synthetic_responses.csv", stringsAsFactors = FALSE)

# true_profile is held aside for the recovery check at the end and must not
# touch anything in between.
# Level order matters: read.csv returns a character column, and letting R
# alphabetize it silently misaligns the recovery cross-tabulation later.
truth <- raw %>%
  select(respondent_id, true_profile) %>%
  mutate(true_profile = factor(true_profile, levels = profile_labels))
dat   <- raw %>% select(-true_profile)
org   <- raw %>% select(respondent_id, department, tenure, level)

message("N = ", nrow(dat), "; item-level missingness = ",
        round(mean(is.na(dat[, ITEMS])) * 100, 1), "%")


# ==============================================================================
# SECTION 1: SPLIT SAMPLE
# ==============================================================================
# Discovering a structure and confirming it on the same data is circular, so
# the sample is split 50/50. The full sample is used later for factor score
# extraction so the LPA is not run at half power.

split_idx <- sample(seq_len(nrow(dat)), size = floor(nrow(dat) / 2))
efa_data  <- dat[split_idx, ITEMS]
cfa_data  <- dat[-split_idx, ITEMS]

message("EFA half: n = ", nrow(efa_data), "; CFA half: n = ", nrow(cfa_data))


# ==============================================================================
# SECTION 2: EXPLORATORY FACTOR ANALYSIS
# ==============================================================================
# Oblimin rotation because the constructs are expected to correlate --
# people who find their work clear are plausibly also more engaged.

efa_cor <- cor(efa_data, use = "pairwise.complete.obs")

kmo_result      <- KMO(efa_cor)
bartlett_result <- cortest.bartlett(efa_cor, n = nrow(efa_data))

message("\n--- Data suitability ---")
message("KMO (overall MSA): ", round(kmo_result$MSA, 3))
message("Bartlett: chi-sq(", bartlett_result$df, ") = ",
        round(bartlett_result$chisq, 2), ", p = ",
        format.pval(bartlett_result$p.value, digits = 3))

message("\n--- Parallel analysis ---")
pa <- fa.parallel(efa_data, fa = "fa", fm = "minres", plot = FALSE)
message("Factors suggested: ", pa$nfact)

efa_5 <- fa(efa_data, nfactors = 5, rotate = "oblimin", fm = "minres")
message("\n--- EFA loadings (5 factors, |loading| > .30) ---")
print(efa_5$loadings, cutoff = 0.30, sort = TRUE)


# ==============================================================================
# SECTION 3: CONFIRMATORY FACTOR ANALYSIS
# ==============================================================================
# Two specifications compared on the held-out half. The cross-loadings on i1
# and i7 are theoretically motivated and were specified before looking at
# these data; the constrained model tests whether they earn their place.

model_cross <- '
  Clarity    =~ i1 + i2 + i14
  Enablement =~ i1 + i3 + i4
  Engagement =~ i5 + i6 + i7
  Impact     =~ i9 + i10 + i15
  Autonomy   =~ i7 + i8 + i11 + i12 + i13
'

model_no_cross <- '
  Clarity    =~ i1 + i2 + i14
  Enablement =~ i3 + i4
  Engagement =~ i5 + i6 + i7
  Impact     =~ i9 + i10 + i15
  Autonomy   =~ i8 + i11 + i12 + i13
'

fit_cross <- cfa(model_cross, data = cfa_data,
                 estimator = "MLR", missing = "fiml", std.lv = TRUE)
fit_no_cross <- cfa(model_no_cross, data = cfa_data,
                    estimator = "MLR", missing = "fiml", std.lv = TRUE)

fit_indices <- function(fit, label) {
  m <- fitMeasures(fit, c("chisq.scaled", "df.scaled", "cfi.scaled",
                          "tli.scaled", "rmsea.scaled",
                          "rmsea.ci.lower.scaled", "rmsea.ci.upper.scaled",
                          "srmr"))
  tibble(
    Model = label,
    chisq = round(unname(m["chisq.scaled"]), 2),
    df    = unname(m["df.scaled"]),
    CFI   = round(unname(m["cfi.scaled"]), 3),
    TLI   = round(unname(m["tli.scaled"]), 3),
    RMSEA = round(unname(m["rmsea.scaled"]), 3),
    RMSEA_lo = round(unname(m["rmsea.ci.lower.scaled"]), 3),
    RMSEA_hi = round(unname(m["rmsea.ci.upper.scaled"]), 3),
    SRMR  = round(unname(m["srmr"]), 3)
  )
}

cfa_comparison <- bind_rows(
  fit_indices(fit_cross,    "Cross-loading"),
  fit_indices(fit_no_cross, "No cross-loading")
)

message("\n--- CFA model comparison ---")
print(as.data.frame(cfa_comparison), row.names = FALSE)

message("\n--- Chi-square difference test ---")
chisq_diff <- anova(fit_no_cross, fit_cross)
print(chisq_diff)

# Retain the better-fitting specification. Expect the cross-loading model to
# win, since the cross-loadings are in the generating model.
final_model <- if (fitMeasures(fit_cross, "cfi.scaled") >
                   fitMeasures(fit_no_cross, "cfi.scaled")) {
  message("\nRetained: cross-loading model")
  model_cross
} else {
  message("\nRetained: constrained model -- unexpected, check the simulation")
  model_no_cross
}

message("\n--- Standardized loadings (retained model) ---")
# lavaan renamed this column across versions: "z.value" in <= 0.6-17,
# "z" from 0.6-18 onward. Resolve it rather than pinning a version.
std_sol <- standardizedSolution(fit_cross)
z_col   <- intersect(c("z", "z.value"), names(std_sol))[1]

loadings_table <- std_sol %>%
  filter(op == "=~") %>%
  select(Factor = lhs, Item = rhs, beta = est.std, se,
         z = all_of(z_col), p = pvalue) %>%
  mutate(across(c(beta, se, z), ~round(.x, 3)))
print(as.data.frame(loadings_table), row.names = FALSE)


# ==============================================================================
# SECTION 4: FACTOR SCORE EXTRACTION
# ==============================================================================
# The structure was validated on held-out data above; the winning model is
# refit on the full sample here purely to get the best-estimated scores for
# every respondent.

fit_scoring <- cfa(final_model, data = dat[, ITEMS],
                   estimator = "MLR", missing = "fiml", std.lv = TRUE)

scores <- lavPredict(fit_scoring, method = "regression") %>%
  as.data.frame() %>%
  setNames(paste0("w_", FACTORS))

scored <- bind_cols(dat %>% select(respondent_id), scores)

message("\n--- Factor score descriptives ---")
score_desc <- scored %>%
  pivot_longer(starts_with("w_"), names_to = "Factor", values_to = "Score") %>%
  group_by(Factor) %>%
  summarise(N = sum(!is.na(Score)),
            Mean = round(mean(Score, na.rm = TRUE), 3),
            SD   = round(sd(Score,   na.rm = TRUE), 3),
            Min  = round(min(Score,  na.rm = TRUE), 2),
            Max  = round(max(Score,  na.rm = TRUE), 2),
            .groups = "drop")
print(as.data.frame(score_desc), row.names = FALSE)

message("\n--- Inter-factor correlations (regression scores) ---")
print(round(cor(scores, use = "complete.obs"), 3))


# ==============================================================================
# SECTION 5: LPA MODEL GRID (18 SPECIFICATIONS)
# ==============================================================================
#   Model 1: equal variances,   zero covariances
#   Model 2: varying variances, zero covariances
#   Model 6: equal variances,   equal covariances
#
# Selection criteria (Nylund et al., 2007; Spurk et al., 2020):
#   BIC     lower is better, read for an elbow rather than a raw minimum
#   Entropy >= .80 for adequate classification (Celeux & Soromenho, 1996)
#   BLRT    significant p indicates k fits better than k-1
#   n_min   smallest profile >= 5% of sample

lpa_input <- scored %>% select(starts_with("w_")) %>% drop_na()
message("\nLPA n = ", nrow(lpa_input))

lpa_grid <- lpa_input %>%
  estimate_profiles(
    n_profiles  = 1:6,
    variances   = c("equal",   "varying", "equal"),
    covariances = c("zero",    "zero",    "equal")
  )

grid_fit <- get_fit(lpa_grid) %>%
  select(any_of(c("Model", "Classes", "LogLik", "AIC", "BIC",
                  "Entropy", "n_min", "n_max", "BLRT_p"))) %>%
  mutate(across(any_of(c("LogLik", "AIC", "BIC")), ~round(.x, 1)),
         across(any_of(c("Entropy", "n_min", "n_max")), ~round(.x, 3)))

message("\n--- LPA model comparison (all 18 specifications) ---")
print(as.data.frame(grid_fit), row.names = FALSE)

# --- Selection diagnostics ----------------------------------------------------
# BIC in finite mixture models frequently declines monotonically, so the raw
# minimum is not the criterion -- the point of diminishing returns is
# (Nylund et al., 2007; Masyn, 2013). The elbow is located as the last k whose
# improvement over k-1 retains a meaningful share of the previous improvement.

ELBOW_THRESHOLD <- 0.25   # k is past the elbow once it retains < 25% of the
                          # previous BIC improvement

m2 <- grid_fit %>% filter(Model == 2) %>% arrange(Classes)

bic_delta <- c(NA, diff(m2$BIC))                       # improvement at each k
delta_ratio <- c(NA, NA, bic_delta[-(1:2)] / bic_delta[-c(1, length(bic_delta))])

selection <- tibble(
  Classes     = m2$Classes,
  BIC         = m2$BIC,
  BIC_delta   = round(bic_delta, 1),
  pct_of_prev = round(delta_ratio * 100, 1),
  Entropy     = m2$Entropy,
  n_min_pct   = round(m2$n_min * 100, 1),
  BLRT_p      = round(m2$BLRT_p, 4)
)

message("\n--- Selection diagnostics (Model 2) ---")
print(as.data.frame(selection), row.names = FALSE)

past_elbow <- which(delta_ratio < ELBOW_THRESHOLD)
elbow_k    <- if (length(past_elbow)) m2$Classes[past_elbow[1]] - 1L else max(m2$Classes)

ent_k4  <- m2$Entropy[m2$Classes == 4]
nmin_k4 <- m2$n_min[m2$Classes == 4]

message("\n--- Selection check (Model 2) ---")
message("BIC elbow at k = ", elbow_k,
        "  (raw BIC minimum at k = ", m2$Classes[which.min(m2$BIC)],
        ", which is not the criterion)")
message("Entropy at k = 4: ", ent_k4)
message("Smallest class at k = 4: ", round(nmin_k4 * 100, 1), "%")
message("BLRT significant through k = ",
        max(m2$Classes[!is.na(m2$BLRT_p) & m2$BLRT_p < .05]),
        " -- does not discriminate among solutions")

if (elbow_k != 4 || is.na(ent_k4) || ent_k4 < 0.80 || nmin_k4 < 0.05) {
  warning(
    "The k = 4 solution is not clearly supported. Do not proceed to export.\n",
    "  Entropy < .80 or elbow past k = 4 -> LOWER SD_MULT[3:5] in 01_simulate.R\n",
    "  Entropy > .97 (implausibly clean) -> RAISE SD_MULT[3:5]\n",
    "  Parallel analysis < 5 factors     -> RAISE SD_MULT[1:2]\n",
    "Re-run 01_simulate.R, then this script.",
    call. = FALSE
  )
} else {
  message("\nk = 4 supported: BIC elbow, entropy above .80, all classes above 5%.")
}


# ==============================================================================
# SECTION 6: FINAL SOLUTION
# ==============================================================================

lpa_final <- lpa_input %>%
  estimate_profiles(n_profiles = 4, variances = "varying", covariances = "zero")

final_data <- get_data(lpa_final)

membership <- scored %>%
  drop_na(starts_with("w_")) %>%
  select(respondent_id) %>%
  bind_cols(final_data %>% select(Class, starts_with("CPROB")))

profile_key <- membership %>%
  left_join(scored, by = "respondent_id") %>%
  group_by(Class) %>%
  summarise(n = n(), across(starts_with("w_"), ~mean(.x, na.rm = TRUE)),
            .groups = "drop") %>%
  mutate(Overall = rowMeans(select(., starts_with("w_")))) %>%
  arrange(Overall) %>%
  mutate(Profile = factor(profile_labels, levels = profile_labels)) %>%
  select(Class, Profile, n, everything(), -Overall)

message("\n--- Four-profile solution ---")
print(as.data.frame(profile_key %>%
        mutate(pct = round(n / sum(n) * 100, 1),
               across(starts_with("w_"), ~round(.x, 3)))), row.names = FALSE)

analysis <- scored %>%
  left_join(membership %>% select(respondent_id, Class), by = "respondent_id") %>%
  left_join(profile_key %>% select(Class, Profile), by = "Class") %>%
  left_join(dat %>% select(respondent_id, oe_worked, oe_hard), by = "respondent_id")


# ==============================================================================
# SECTION 7: CLASSIFICATION ACCURACY
# ==============================================================================

avepp <- membership %>%
  pivot_longer(starts_with("CPROB"), names_to = "col", values_to = "prob") %>%
  mutate(col_class = as.integer(str_extract(col, "\\d+"))) %>%
  filter(as.integer(Class) == col_class) %>%
  group_by(Class) %>%
  summarise(n = n(), AvePP = round(mean(prob, na.rm = TRUE), 3), .groups = "drop") %>%
  left_join(profile_key %>% select(Class, Profile), by = "Class") %>%
  select(Profile, n, AvePP)

message("\n--- Average posterior probability by profile (>= .80 adequate) ---")
print(as.data.frame(avepp), row.names = FALSE)


# ==============================================================================
# SECTION 8: RECOVERY CHECK
# ==============================================================================
# Diagnostic only. Compares the estimated solution against known membership --
# something available here precisely because the data are synthetic, and not
# available in any real application.

recovery <- analysis %>%
  left_join(truth, by = "respondent_id") %>%
  filter(!is.na(Profile), !is.na(true_profile))

recovery_tab <- table(True      = factor(recovery$true_profile, levels = profile_labels),
                      Estimated = factor(recovery$Profile,      levels = profile_labels))

# Computed by label match rather than diag(), which silently reads the wrong
# cells whenever the two factors carry different level orders.
recovery_rate <- mean(as.character(recovery$true_profile) ==
                      as.character(recovery$Profile))

message("\n--- Recovery: true vs. estimated profile ---")
print(recovery_tab)
message("Agreement: ", round(recovery_rate * 100, 1), "%")


# ==============================================================================
# SECTION 8B: CONVENTIONAL SEGMENTATION vs. PROFILES
# ==============================================================================
# The comparison the demo turns on. Employee listening programs segment by what
# the HRIS provides. If those cuts are flat while the profile cut is not, the
# case for person-centered analysis makes itself.

analysis <- analysis %>% left_join(org, by = "respondent_id")

factor_cols <- paste0("w_", FACTORS)

# --- Mean factor score by conventional segment -------------------------------

segment_means <- function(data, var) {
  data %>%
    filter(!is.na(.data[[var]])) %>%
    group_by(segment = as.character(.data[[var]])) %>%
    summarise(n = n(),
              across(all_of(factor_cols), ~round(mean(.x, na.rm = TRUE), 3)),
              .groups = "drop") %>%
    mutate(attribute = var, .before = 1)
}

segments <- bind_rows(
  segment_means(analysis, "department"),
  segment_means(analysis, "tenure"),
  segment_means(analysis, "level")
)

message("\n--- Mean factor score by conventional segment ---")
print(as.data.frame(segments), row.names = FALSE)

# --- Widest gap available under each segmentation ----------------------------
# The headline contrast: the largest difference any conventional cut can
# produce, against the largest difference the profile solution produces.

spread <- function(df, group_col) {
  df %>%
    pivot_longer(all_of(factor_cols), names_to = "factor", values_to = "mean") %>%
    group_by(.data[[group_col]], factor) %>%
    summarise(mean = mean(mean), .groups = "drop_last") %>%
    group_by(factor, .add = FALSE) %>%
    summarise(gap = max(mean) - min(mean), .groups = "drop")
}

conventional_gaps <- segments %>%
  group_by(attribute) %>%
  group_modify(~ {
    .x %>%
      pivot_longer(all_of(factor_cols), names_to = "factor", values_to = "mean") %>%
      group_by(factor) %>%
      summarise(gap = round(max(mean) - min(mean), 3), .groups = "drop")
  }) %>%
  ungroup()

profile_gaps <- profile_key %>%
  pivot_longer(all_of(factor_cols), names_to = "factor", values_to = "mean") %>%
  group_by(factor) %>%
  summarise(gap = round(max(mean) - min(mean), 3), .groups = "drop") %>%
  mutate(attribute = "PROFILE", .before = 1)

gap_comparison <- bind_rows(conventional_gaps, profile_gaps) %>%
  pivot_wider(names_from = factor, values_from = gap) %>%
  mutate(widest = do.call(pmax, across(starts_with("w_"))))

message("\n--- Widest gap between segments, by segmentation scheme ---")
print(as.data.frame(gap_comparison), row.names = FALSE)

max_conventional <- max(conventional_gaps$gap)
max_profile      <- max(profile_gaps$gap)
message("\nWidest conventional gap: ", round(max_conventional, 3), " SD")
message("Widest profile gap:      ", round(max_profile, 3), " SD  (",
        round(max_profile / max_conventional, 1), "x larger)")

# --- Is profile membership associated with any attribute? --------------------
# Chi-square with Cramer's V, Holm-corrected across the three simultaneous
# tests. Expected to be null: that is the point.

profile_chisq <- function(data, var) {
  tbl <- table(data[[var]], data$Profile)
  res <- chisq.test(tbl)
  n   <- sum(tbl); k <- min(dim(tbl))
  tibble(attribute = var,
         chisq     = round(unname(res$statistic), 2),
         df        = unname(res$parameter),
         p_raw     = res$p.value,
         cramers_v = round(sqrt(unname(res$statistic) / (n * (k - 1))), 3),
         n         = n)
}

assoc <- bind_rows(
  profile_chisq(analysis %>% filter(!is.na(Profile)), "department"),
  profile_chisq(analysis %>% filter(!is.na(Profile)), "tenure"),
  profile_chisq(analysis %>% filter(!is.na(Profile)), "level")
) %>%
  mutate(p_adj = round(p.adjust(p_raw, method = "holm"), 4),
         p_raw = round(p_raw, 4),
         significant = p_adj < .05)

message("\n--- Profile membership by organizational attribute ---")
print(as.data.frame(assoc), row.names = FALSE)
message("Non-significant results mean the profiles cut across the org chart --")
message("no conventional segmentation would surface them.")

# --- Profile composition within each segment ---------------------------------
# Feeds the UI: every department contains roughly the same profile mix.

composition <- bind_rows(
  analysis %>% filter(!is.na(Profile)) %>% count(attribute = "department",
              segment = department, Profile),
  analysis %>% filter(!is.na(Profile)) %>% count(attribute = "tenure",
              segment = as.character(tenure), Profile),
  analysis %>% filter(!is.na(Profile)) %>% count(attribute = "level",
              segment = as.character(level), Profile)
) %>%
  group_by(attribute, segment) %>%
  mutate(pct = round(n / sum(n) * 100, 1)) %>%
  ungroup() %>%
  mutate(Profile = as.character(Profile))


# ==============================================================================
# SECTION 9: OPEN-TEXT RESPONSE BEHAVIOR
# ==============================================================================
# Response behavior is treated as data in its own right, not as missingness.

DISMISSALS <- c("nothing", "n/a", "no", "none", "idk", "not really",
                "nope", "na", "nothing.", "nothin")

word_count <- function(x) {
  ifelse(is.na(x), NA_integer_,
         str_count(str_trim(x), "\\S+"))
}

is_dismissal <- function(x) {
  cleaned <- str_to_lower(str_trim(str_remove_all(x, "[[:punct:]]+$")))
  !is.na(x) & cleaned %in% str_remove_all(DISMISSALS, "[[:punct:]]+$")
}

oe_behavior <- function(data, col, label) {
  data %>%
    filter(!is.na(Profile)) %>%
    mutate(txt = .data[[col]],
           skipped    = is.na(txt),
           words      = word_count(txt),
           one_word   = !skipped & words == 1,
           dismissal  = is_dismissal(txt)) %>%
    group_by(Profile) %>%
    summarise(
      Prompt        = label,
      N             = n(),
      n_skipped     = sum(skipped),
      pct_skipped   = round(mean(skipped) * 100, 1),
      n_responded   = sum(!skipped),
      pct_one_word  = round(sum(one_word)  / sum(!skipped) * 100, 1),
      pct_dismissal = round(sum(dismissal) / sum(!skipped) * 100, 1),
      median_words  = median(words[!skipped], na.rm = TRUE),
      mean_words    = round(mean(words[!skipped], na.rm = TRUE), 1),
      sd_words      = round(sd(words[!skipped],   na.rm = TRUE), 1),
      .groups = "drop"
    ) %>%
    select(Prompt, Profile, everything())
}

oe_worked <- oe_behavior(analysis, "oe_worked", "What worked")
oe_hard   <- oe_behavior(analysis, "oe_hard",   "What was hard")

message("\n--- Response behavior: 'What worked' ---")
print(as.data.frame(oe_worked), row.names = FALSE)

message("\n--- Response behavior: 'What was hard' ---")
print(as.data.frame(oe_hard), row.names = FALSE)

message("\nExpected inversion: skip rate should DESCEND across profiles on the")
message("first prompt and ASCEND on the second.")


# ==============================================================================
# SAVE FOR EXPORT
# ==============================================================================

saveRDS(
  list(
    kmo            = kmo_result$MSA,
    bartlett       = bartlett_result,
    parallel_n     = pa$nfact,
    cfa_comparison = cfa_comparison,
    chisq_diff     = chisq_diff,
    loadings       = loadings_table,
    score_desc     = score_desc,
    score_cor      = cor(scores, use = "complete.obs"),
    grid_fit       = grid_fit,
    selection      = selection,
    elbow_k        = elbow_k,
    profile_key    = profile_key,
    avepp          = avepp,
    recovery_tab   = recovery_tab,
    recovery_rate  = recovery_rate,
    segments         = segments,
    gap_comparison   = gap_comparison,
    max_conventional = max_conventional,
    max_profile      = max_profile,
    assoc            = assoc,
    composition      = composition,
    oe_worked      = oe_worked,
    oe_hard        = oe_hard,
    lpa_input      = lpa_input,
    analysis       = analysis
  ),
  "data/fitted_objects.rds"
)

message("\nSaved data/fitted_objects.rds")
message("Note: 03_export_json.R also needs the k = 3 and k = 5 solutions of")
message("Model 2 for the comparison panel; it refits them from lpa_input.")
