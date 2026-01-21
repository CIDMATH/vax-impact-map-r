# Calibrate pneumococcal model parameters using observed national level data 
# --------------------------------------------------------------------------

calibrate_pneumo <- function(df) {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/calibrate_pneumo.R"))
  print("--3. calibrate_pneumo.R")
  
  ## Filter the model data for just pneumococcal
  # --------------------------------------------------------------------------
  df <- df %>% filter(disease=='Pneumococcal')
  
  ## Run pneumococcal hospitalization calibration based on observed data
  # --------------------------------------------------------------------------
  read_path_calibrate_pneumo_hospitalizations_r <- here("R/calibrate_pneumo_hospitalizations.R")
  source(read_path_calibrate_pneumo_hospitalizations_r)
  df <- calibrate_pneumo_hospitalizations(df)
  
  ## Run pneumococcal death calibration
  # --------------------------------------------------------------------------
  read_path_calibrate_pneumo_deaths_r <- here("R/calibrate_pneumo_deaths.R")
  source(read_path_calibrate_pneumo_deaths_r)
  df <- calibrate_pneumo_deaths(df)
  
  ## Run pneumococcal case calibration
  # --------------------------------------------------------------------------
  read_path_calibrate_pneumo_cases_r <- here("R/calibrate_pneumo_cases.R")
  source(read_path_calibrate_pneumo_cases_r)
  df <- calibrate_pneumo_cases(df)
  
  return(df)
  
}