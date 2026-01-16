# ----------------------get_and_process_data.R------------------------------

get_and_process_data <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidycensus","tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  here::i_am("R/get_and_process_data.R")
  
  # Source and run functions for getting and processing data
  # --------------------------------------------------------------------------

  ### CDC DATA
  # --------------------------------------------------------------------------
  
  ## GET DATA
  
  # get_data_cdc_child_vax_view.R
  read_path_get_data_cdc_child_vax_view_r <- here("R/get_data_cdc_child_vax_view.R")
  source(read_path_get_data_cdc_child_vax_view_r)
  get_data_cdc_child_vax_view()
  
  # get_data_cdc_school_vax_view.R
  read_path_get_data_cdc_school_vax_view_r <- here("R/get_data_cdc_school_vax_view.R")
  source(read_path_get_data_cdc_school_vax_view_r)
  get_data_cdc_school_vax_view()
  
  ## PROCESS DATA
  
  # process_data_cdc_child_vax_view_rotavirus.R
  read_path_process_data_cdc_child_vax_view_rotavirus_r <- here("R/process_data_cdc_child_vax_view_rotavirus.R")
  source(read_path_process_data_cdc_child_vax_view_rotavirus_r)
  process_data_cdc_child_vax_view_rotavirus()
  
  # process_data_cdc_school_vax_view_dtap.R
  read_path_process_data_cdc_school_vax_view_dtap_r <- here("R/process_data_cdc_school_vax_view_dtap.R")
  source(read_path_process_data_cdc_school_vax_view_dtap_r)
  process_data_cdc_school_vax_view_dtap()
  
  ### CENSUS ACS DATA
  # --------------------------------------------------------------------------
  
  ## GET DATA
  
  # get_data_census_acs_states.R
  read_path_get_data_census_acs_states_r <- here("R/get_data_census_acs_states.R")
  source(read_path_get_data_census_acs_states_r)
  get_data_census_acs_states()
  
  # get_data_census_acs_state_population_0_4_years.R
  read_path_get_data_census_acs_state_population_0_4_years_r <- here("R/get_data_census_acs_state_population_0_4_years.R")
  source(read_path_get_data_census_acs_state_population_0_4_years_r)
  get_data_census_acs_state_population_0_4_years()
  
  # get_data_census_acs_state_population_0_14_years.R
  read_path_get_data_census_acs_state_population_0_14_years_r <- here("R/get_data_census_acs_state_population_0_14_years.R")
  source(read_path_get_data_census_acs_state_population_0_14_years_r)
  get_data_census_acs_state_population_0_14_years()
  
  # get_data_census_acs_state_population.R
  read_path_get_data_census_acs_state_population_r <- here("R/get_data_census_acs_state_population.R")
  source(read_path_get_data_census_acs_state_population_r)
  get_data_census_acs_state_population()
  
  ### MODEL INPUT PARAMETERS
  # --------------------------------------------------------------------------
  
  ## GET DATA
  
  # get_data_model_input_parameters.R
  read_path_get_data_model_input_parameters_r <- here("R/get_data_model_input_parameters.R")
  source(read_path_get_data_model_input_parameters_r)
  get_data_model_input_parameters()

}