# Function that runs all functions for getting data
# --------------------------------------------------------------------------
process_data <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidycensus","tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/process_data.R"))
  print("-B. process_data.R")
  
  # Source and run functions for processing data
  # --------------------------------------------------------------------------
  
  # Process CDC data
  read_path_process_data_cdc_r <- here("R/process_data_cdc.R")
  source(read_path_process_data_cdc_r)
  process_data_cdc()

}