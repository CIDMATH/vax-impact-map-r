# Calibrate rotavirus model parameters using observed national level data 
# --------------------------------------------------------------------------

calibrate_rota_cases <- function(df) {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/calibrate_rota_cases.R"))
  print("---b. calibrate_rota_cases.R")
  
  ## Back-calculate rotavirus cases using the combination of calibrated hospitalization and P(hospitalized|case)
  # --------------------------------------------------------------------------
  df$cases <- df$hospitalizations / df$proportion_hospitalized_given_case
  df$cases_per_100k <- df$cases / df$age_group_population * 100000
  
  return(df)
  
}