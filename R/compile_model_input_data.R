# ----------------------compile_model_input_data.R--------------------------

## Function to compile model input data
# --------------------------------------------------------------------------

compile_model_input_data <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  here::i_am("R/compile_model_input_data.R")

  ## Read in data
  # --------------------------------------------------------------------------
  read_path_read_data_r <- here("R/read_data.R")
  source(read_path_read_data_r)
  read_data()
  
  ## Compile model input data
  # --------------------------------------------------------------------------
  df_census <- left_join(census_acs_states_df, census_acs_state_population_df %>% select(-state_name), by = c("state_fips_code" = "state_fips_code"))
  df_census <- left_join(df_census, census_acs_state_population_0_4_years_df %>% select(-state_name), by = c("state_fips_code" = "state_fips_code"))
  df_census <- left_join(df_census, census_acs_state_population_0_14_years_df %>% select(-state_name), by = c("state_fips_code" = "state_fips_code"))
  df_rota <- left_join(df_census, cdc_child_vax_view_rotavirus_df, by = c("state_name" = "state_name"))
  df_dtap <- left_join(df_census, cdc_school_vax_view_dtap_df, by = c("state_name" = "state_name")) %>% mutate(vaccine_coverage_estimate = as.numeric(vaccine_coverage_estimate))
  df_census_cdc <- union(df_rota,df_dtap)
  df <- left_join(df_census_cdc, model_input_parameters_df, by = c("vaccine" = "vaccine")) %>% select(-ends_with("_source"))

}