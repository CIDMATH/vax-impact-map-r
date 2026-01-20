# Function to compute incidence at endemic equilibrium 
# --------------------------------------------------------------------------

compute_ee_incidence <- function(df) {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  here::i_am("R/compute_ee_incidence.R")
  
  ## Apply a naive assumption that the population of all birth cohorts, past and future, comprising the age group band of interest is the same
  # ex. If the age band of interest for rotavirus is age 0-4 years and the population is 100, then assume 0-1y, 1-2y, 2-3y, 3-4y, 4-5y all has population of 20 an that that pattern will continue for future birth cohorts
  # --------------------------------------------------------------------------
  population_turnover_rate_annual = 1 / df$age_group_length
  
  ## Calculate recovery rate based on number of days infectious
  # --------------------------------------------------------------------------
  recovery_rate_annual = 365/df$duration_infectious_days
  
  ## Get annual waning rate
  # --------------------------------------------------------------------------
  waning_rate_annual = df$waning_rate_annual
  
  ## Compute incidence at endemic equilibrium
  # --------------------------------------------------------------------------
  ee_incidence_core = 1 - 1 / (df$basic_reproduction_number * (1 - df$effective_structural_vaccine_coverage))
  
  # If SIR, then incidence_rate_annual is annual_turnover_rate * ee_incidence_core
  # If SIRS, then incidence_rate_annual is (((recovery_rate_annual + population_turnover_rate_annual) * (population_turnover_rate_annual + waning_rate_annual)) / (recovery_rate_annual + population_turnover_rate_annual + waning_rate_annual)) * ee_incidence_core
  df$endemic_equilibrium_incidence_rate_annual <- ifelse(df$model_type=='SIR', population_turnover_rate_annual * ee_incidence_core, (((recovery_rate_annual + population_turnover_rate_annual) * (population_turnover_rate_annual + waning_rate_annual)) / (recovery_rate_annual + population_turnover_rate_annual + waning_rate_annual)) * ee_incidence_core)
  
  return(df)
  
}