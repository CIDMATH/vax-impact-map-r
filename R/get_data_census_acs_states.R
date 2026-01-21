# Create function get_data_census_acs_states by calling the census ACS API from tidycensus
# --------------------------------------------------------------------------
get_data_census_acs_states <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidycensus","tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/get_data_census_acs_states.R"))
  print("---a. get_data_census_acs_states.R")
  
  # Get state data from Census ACS
  df_state <- suppressMessages(
                get_acs(geography = "state", 
                  variables = "B01001_001",
                  year = 2020, 
                  geometry = FALSE)
              ) %>% 
              select(GEOID, NAME) %>% 
              rename(state_fips_code = GEOID,
                     state_name = NAME)
  
  # Get nation data from Census ACS
  df_nation <- suppressMessages(
                 get_acs(geography = "us", 
                  variables = "B01001_001",
                  year = 2020, 
                  geometry = FALSE)
                ) %>% 
                select(GEOID, NAME) %>% 
                rename(state_fips_code = GEOID,
                       state_name = NAME)
  
  # Union state and nation data
  df <- union(df_state,df_nation)
  
  # Write data as a rds called census_acs_states.rds to the project `data-raw` folder
  write_path_rds <- here("data-raw/census_acs_states.rds")
  saveRDS(df, file = write_path_rds)
  
  # Message specifying where data was written
  # print(paste0("Saved state data to ",write_path_rds))
  
  # Write data as a csv called census_acs_states.csv to the project `data-raw` folder
  write_path_csv <- here("data-raw/csv/census_acs_states.csv")
  write.csv(df, file = write_path_csv)
  
  # Message specifying where data was written
  # print(paste0("Saved state data to ",write_path_csv))
  
}