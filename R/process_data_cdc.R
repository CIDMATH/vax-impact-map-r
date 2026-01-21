# Function that runs all functions for processing CDC data
# --------------------------------------------------------------------------
process_data_cdc <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/process_data_cdc.R"))
  print("--1. process_data_cdc.R")
  
  # process_data_cdc_child_vax_view.R
  read_path_process_data_cdc_child_vax_view_r <- here("R/process_data_cdc_child_vax_view.R")
  source(read_path_process_data_cdc_child_vax_view_r)
  process_data_cdc_child_vax_view()
  
  # process_data_cdc_school_vax_view.R
  read_path_process_data_cdc_school_vax_view_dtap_r <- here("R/process_data_cdc_school_vax_view.R")
  source(read_path_process_data_cdc_school_vax_view_dtap_r)
  process_data_cdc_school_vax_view()

}