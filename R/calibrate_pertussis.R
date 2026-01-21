# Calibrate pertussis model parameters using observed national level data 
# --------------------------------------------------------------------------

calibrate_pertussis <- function(df) {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/calibrate_pertussis.R"))
  print("--2. calibrate_pertussis.R")
  
  ## Filter the model data for just pertussis
  # --------------------------------------------------------------------------
  df <- df %>% filter(disease=='Pertussis')
  
  ## Run pertussis case calibration
  # --------------------------------------------------------------------------
  read_path_calibrate_pertussis_cases_r <- here("R/calibrate_pertussis_cases.R")
  source(read_path_calibrate_pertussis_cases_r)
  df <- calibrate_pertussis_cases(df)
  
  ## Run pertussis hospitalization calibration based on observed data
  # --------------------------------------------------------------------------
  read_path_calibrate_pertussis_hospitalizations_r <- here("R/calibrate_pertussis_hospitalizations.R")
  source(read_path_calibrate_pertussis_hospitalizations_r)
  df <- calibrate_pertussis_hospitalizations(df)
  
  ## Run pertussis death calibration
  # --------------------------------------------------------------------------
  read_path_calibrate_pertussis_deaths_r <- here("R/calibrate_pertussis_deaths.R")
  source(read_path_calibrate_pertussis_deaths_r)
  df <- calibrate_pertussis_deaths(df)
  
  return(df)
  
}