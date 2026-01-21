# Compute incidence at endemic equilibrium by scenario for the diseases of interest
# --------------------------------------------------------------------------

calculate_structural_vaccine_coverage <- function(df) {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/calculate_structural_vaccine_coverage.R"))
  print("-C. calculate_structural_vaccine_coverage.R")
  
  ## Calculate vaccine coverage among birth cohorts impacted by declining vaccine coverage
  df$coverage_with_decline_applied <- pmax(df$vaccine_coverage_estimate - df$declining_coverage_among_new_births,0)
  
  ## Calculate structural vaccine coverage
  # --------------------------------------------------------------------------
  
  # Consider when the time horizon is larger than the size of the size of the age group...
  
  # The entire age group will reflect the declining coverage from the current baseline vaccine coverage estimate.
  # Otherwise, some birth cohorts will be impacted by the declining coverage (declining coverage component) while some will not (baseline coverage component)
  # Also, coverage cannot drop below 0 so use pmax to ensure coverage is not negative
  df$structural_vaccine_coverage <- ifelse(df$time_horizon > df$age_group_length,
                                           df$coverage_with_decline_applied,
                                           (((df$age_group_length - df$time_horizon) * df$vaccine_coverage_estimate) + # baseline coverage component
                                              ((df$time_horizon) * df$coverage_with_decline_applied)) / # declined coverage component
                                             df$age_group_length)
  
  ## Calculate effective structural vaccine coverage by multiplying structural vaccine coverage by vaccine effectiveness
  # --------------------------------------------------------------------------
  df$effective_structural_vaccine_coverage <- df$structural_vaccine_coverage * df$vaccine_effectiveness
  
  return(df)
  
}