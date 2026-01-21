# Function that runs all functions for getting data
# --------------------------------------------------------------------------
get_data <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidycensus","tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/get_data.R"))
  print("-A. get_data.R")
  
  # Source and run functions for getting data
  # --------------------------------------------------------------------------
  
  # Get CDC data
  read_path_get_data_cdc_r <- here("R/get_data_cdc.R")
  source(read_path_get_data_cdc_r)
  get_data_cdc()
  
  # Get census data
  read_path_get_data_census_r <- here("R/get_data_census.R")
  source(read_path_get_data_census_r)
  get_data_census()
  
  # Get model input parameter data
  read_path_get_data_model_input_parameters <- here("R/get_data_model_input_parameters.R")
  source(read_path_get_data_model_input_parameters)
  get_data_model_input_parameters()

}