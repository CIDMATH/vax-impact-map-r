# Function that runs all functions for getting CDC data
# --------------------------------------------------------------------------
get_data_cdc <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidycensus","tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/get_data_cdc.R"))
  print("--1. get_data_cdc.R")
  
  # Source and run functions for getting data
  # --------------------------------------------------------------------------
  
  # get_data_cdc_child_vax_view.R
  read_path_get_data_cdc_child_vax_view_r <- here("R/get_data_cdc_child_vax_view.R")
  source(read_path_get_data_cdc_child_vax_view_r)
  get_data_cdc_child_vax_view()
  
  # get_data_cdc_school_vax_view.R
  read_path_get_data_cdc_school_vax_view_r <- here("R/get_data_cdc_school_vax_view.R")
  source(read_path_get_data_cdc_school_vax_view_r)
  get_data_cdc_school_vax_view()

}