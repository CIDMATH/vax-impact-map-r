# Calibrate rotavirus model parameters using observed national level data 
# --------------------------------------------------------------------------

calibrate_rota <- function(df) {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/calibrate_rota.R"))
  print("--1. calibrate_rota.R")
  
  ## Filter the model data for just rotavirus
  # --------------------------------------------------------------------------
  df <- df %>% filter(disease=='Rotavirus')
  
  ## Run rotavirus hospitalization calibration based on observed data
  # --------------------------------------------------------------------------
  read_path_calibrate_rota_hospitalizations_r <- here("R/calibrate_rota_hospitalizations.R")
  source(read_path_calibrate_rota_hospitalizations_r)
  df <- calibrate_rota_hospitalizations(df)
  
  ## Run rotavirus case calibration
  # --------------------------------------------------------------------------
  read_path_calibrate_rota_cases_r <- here("R/calibrate_rota_cases.R")
  source(read_path_calibrate_rota_cases_r)
  df <- calibrate_rota_cases(df)
  
  ## Run rotavirus death calibration
  # --------------------------------------------------------------------------
  read_path_calibrate_rota_deaths_r <- here("R/calibrate_rota_deaths.R")
  source(read_path_calibrate_rota_deaths_r)
  df <- calibrate_rota_deaths(df)
  
  return(df)
  
}