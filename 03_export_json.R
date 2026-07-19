# ==============================================================================
# EMPLOYEE EXPERIENCE SURVEY — JSON EXPORT
# ==============================================================================
# Assembles everything the static viewer needs into a single file. The page
# loads this and nothing else -- no server, no runtime estimation.
#
# Input:  data/fitted_objects.rds       (from 02_fit_models.R)
#         data/generating_parameters.rds (from 01_simulate.R)
# Output: data/model_results.json
# ==============================================================================

library(dplyr)
library(tidyr)
library(tidyLPA)
library(jsonlite)

select <- dplyr::select
filter <- dplyr::filter
mutate <- dplyr::mutate

set.seed(20260718)

fit    <- readRDS("data/fitted_objects.rds")
params <- readRDS("data/generating_parameters.rds")

FACTORS        <- params$factors
profile_labels <- params$profile_labels

# Display order puts the structural factors first so the fanning effect reads
# left to right in the profile plot.
FACTOR_ORDER <- c("Clarity", "Enablement", "Engagement", "Impact", "Autonomy")


# ==============================================================================
# SECTION 1: ALTERNATIVE SOLUTIONS (k = 3 and k = 5)
# ==============================================================================
# The UI lets the reader compare adjacent solutions, so those need to be fit
# and labelled the same way the retained solution was.

label_solution <- function(input, k) {
  mod <- estimate_profiles(input, n_profiles = k,
                           variances = "varying", covariances = "zero")
  d <- get_data(mod)

  key <- input %>%
    mutate(Class = d$Class) %>%
    group_by(Class) %>%
    summarise(n = n(), across(starts_with("w_"), ~mean(.x, na.rm = TRUE)),
              .groups = "drop") %>%
    mutate(Overall = rowMeans(select(., starts_with("w_")))) %>%
    arrange(Overall)

  # For k != 4 the four canonical labels do not apply, so profiles are named
  # by rank. Inventing intermediate labels would imply a substantive reading
  # the solution does not support.
  key$Label <- if (k == 4) profile_labels else paste("Profile", seq_len(k))

  key %>%
    mutate(pct = round(n / sum(n) * 100, 1)) %>%
    rowwise() %>%
    mutate(means = list(setNames(
      round(c_across(all_of(paste0("w_", FACTOR_ORDER))), 3),
      FACTOR_ORDER
    ))) %>%
    ungroup() %>%
    select(label = Label, n, pct, means)
}

message("Refitting k = 3 and k = 5 for the comparison panel...")
sol_3 <- label_solution(fit$lpa_input, 3)
sol_5 <- label_solution(fit$lpa_input, 5)

# k = 4 comes from the retained fit rather than being re-estimated, so the
# exported solution is exactly the one the diagnostics describe.
sol_4 <- fit$profile_key %>%
  mutate(pct = round(n / sum(n) * 100, 1)) %>%
  rowwise() %>%
  mutate(means = list(setNames(
    round(c_across(all_of(paste0("w_", FACTOR_ORDER))), 3),
    FACTOR_ORDER
  ))) %>%
  ungroup() %>%
  select(label = Profile, n, pct, means) %>%
  mutate(label = as.character(label))


# ==============================================================================
# SECTION 2: ASSEMBLE
# ==============================================================================

items_json <- lapply(names(params$loadings), function(id) {
  list(
    id      = id,
    text    = unname(params$item_text[[id]]),
    factors = names(params$loadings[[id]])
  )
})

grid_json <- fit$grid_fit %>%
  mutate(
    spec = recode(as.character(Model),
                  "1" = "Equal variances, zero covariances",
                  "2" = "Varying variances, zero covariances",
                  "3" = "Equal variances, equal covariances"),
    n_min_pct = round(n_min * 100, 1),
    retained  = (Model == 2 & Classes == 4)
  ) %>%
  select(model = Model, spec, classes = Classes, logLik = LogLik,
         aic = AIC, bic = BIC, entropy = Entropy,
         n_min_pct, blrt_p = BLRT_p, retained)

selection_json <- fit$selection %>%
  select(classes = Classes, bic = BIC, bic_delta = BIC_delta,
         pct_of_prev, entropy = Entropy, n_min_pct, blrt_p = BLRT_p)

cfa_json <- list(
  kmo        = round(fit$kmo, 3),
  bartlett   = list(chisq = round(unname(fit$bartlett$chisq), 2),
                    df    = unname(fit$bartlett$df),
                    p     = fit$bartlett$p.value),
  parallel_n = fit$parallel_n,
  comparison = fit$cfa_comparison,
  loadings   = fit$loadings %>% select(factor = Factor, item = Item,
                                       beta, se, z, p)
)

score_cor_json <- as.data.frame(round(fit$score_cor, 3)) %>%
  mutate(factor = gsub("^w_", "", rownames(.))) %>%
  select(factor, everything())
names(score_cor_json) <- gsub("^w_", "", names(score_cor_json))

oe_json <- function(tab) {
  tab %>%
    mutate(Profile = as.character(Profile)) %>%
    select(profile = Profile, n = N, pct_skipped, n_responded,
           pct_one_word, pct_dismissal, median_words, mean_words, sd_words)
}

recovery_json <- as.data.frame(fit$recovery_tab) %>%
  rename(true = True, estimated = Estimated, n = Freq)

out <- list(
  meta = list(
    n            = params$n,
    n_items      = length(params$loadings),
    n_factors    = length(FACTORS),
    seed         = params$seed,
    sd_mult      = setNames(as.list(params$sd_mult), FACTORS),
    generated_at = format(Sys.time(), "%Y-%m-%d"),
    synthetic    = TRUE
  ),
  factors    = FACTOR_ORDER,
  items      = items_json,
  cfa        = cfa_json,
  scores     = list(descriptives = fit$score_desc,
                    correlations = score_cor_json),
  grid       = grid_json,
  selection  = selection_json,
  elbow_k    = fit$elbow_k,
  solutions  = list(`3` = sol_3, `4` = sol_4, `5` = sol_5),
  final      = list(
    model         = 2L,
    classes       = 4L,
    avepp         = fit$avepp %>% mutate(Profile = as.character(Profile)) %>%
                      select(profile = Profile, n, avepp = AvePP),
    recovery      = recovery_json,
    recovery_rate = round(fit$recovery_rate, 3)
  ),
  # The comparison the page is built around.
  segmentation = list(
    segments         = fit$segments,
    gap_comparison   = fit$gap_comparison,
    max_conventional = round(fit$max_conventional, 3),
    max_profile      = round(fit$max_profile, 3),
    ratio            = round(fit$max_profile / fit$max_conventional, 1),
    association      = fit$assoc,
    composition      = fit$composition
  ),
  oe = list(worked = oe_json(fit$oe_worked),
            hard   = oe_json(fit$oe_hard))
)

write_json(out, "data/model_results.json",
           auto_unbox = TRUE, digits = 4, pretty = TRUE, na = "null")

message("Wrote data/model_results.json (",
        round(file.size("data/model_results.json") / 1024, 1), " KB)")


# ==============================================================================
# SECTION 3: VERIFY
# ==============================================================================
# Read it back. A JSON that parses but has silently lost a nested structure is
# worse than one that fails loudly.

check <- fromJSON("data/model_results.json", simplifyVector = FALSE)

stopifnot(
  length(check$items) == length(params$loadings),
  length(check$grid) == 18,
  all(c("3", "4", "5") %in% names(check$solutions)),
  length(check$solutions$`4`) == 4,
  length(check$oe$worked) == 4,
  length(check$oe$hard) == 4,
  length(check$segmentation$association) == 3,
  !is.null(check$segmentation$ratio)
)

message("\n--- Export summary ---")
message("Items:            ", length(check$items))
message("Grid rows:        ", length(check$grid))
message("Solutions:        k = ", paste(names(check$solutions), collapse = ", "))
message("Elbow at:         k = ", check$elbow_k)
message("Recovery:         ", round(check$final$recovery_rate * 100, 1), "%")
message("Widest conventional gap: ", check$segmentation$max_conventional, " SD")
message("Widest profile gap:      ", check$segmentation$max_profile,
        " SD (", check$segmentation$ratio, "x)")
message("\nVerification passed. data/model_results.json is ready for index.html.")
