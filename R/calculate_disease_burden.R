# Calculate disease burden based on calibrated cases
# --------------------------------------------------------------------------

calculate_disease_burden <- function(df) {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/calculate_disease_burden.R"))
  
  # Using infections, determine hospitalizations and deaths
  # --------------------------------------------------------------------------
  df$hospitalizations <- df$infections * df$proportion_hospitalized_given_case
  df$hospitalizations_per_100k <- df$hospitalizations / df$age_group_population * 100000
  
  df$deaths <- df$infections * df$death_rate
  df$deaths_per_100k <- df$deaths / df$age_group_population * 100000
  
  return(df)
  
}