# Create function get_data_census_acs_state_population for retrieving Census ACS 2019-2023 5 year total population estimates
# --------------------------------------------------------------------------
get_data_census_acs_state_population <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidycensus","tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/get_data_census_acs_state_population.R"))
  print("---d. get_data_census_acs_state_population.R")
  
  # Create function get_data_census_acs_state_population by calling the census ACS API from tidycensus
  # --------------------------------------------------------------------------
  
  # Get state data from Census ACS
  df_state <- suppressMessages(
                get_acs(geography = "state", 
                            variables = "B01001_001E", # Total Population
                            year = 2023, 
                            geometry = FALSE)
                ) %>% 
                group_by(GEOID, NAME) %>%
                summarise(.groups="keep", total_population = sum(estimate)) %>%
                rename(state_fips_code = GEOID,
                       state_name = NAME) %>%
                ungroup()
              
  
  # Get national data from Census ACS
  df_nation <- suppressMessages(
                get_acs(geography = "us", 
                                  variables = "B01001_001E", # Total Population
                                  year = 2023, 
                                  geometry = FALSE)
                ) %>% 
                group_by(GEOID, NAME) %>%
                summarise(.groups="keep", total_population = sum(estimate)) %>%
                rename(state_fips_code = GEOID,
                       state_name = NAME) %>%
                ungroup()
  
  # Union state and nation data
  df <- union(df_state,df_nation)
  
  # Write data as a rds called census_acs_state_population.rds to the project `data-raw` folder
  write_path_rds <- here("data-raw/census_acs_state_population.rds")
  saveRDS(df, file = write_path_rds)
  
  # Message specifying where data was written
  # print(paste0("Saved state data to ",write_path_rds))
  
  # Write data as a csv called census_acs_state_population.csv to the project `data-raw` folder
  write_path_csv <- here("data-raw/csv/census_acs_state_population.csv")
  write.csv(df, file = write_path_csv)
  
  # Message specifying where data was written
  # print(paste0("Saved state data to ",write_path_csv))
  
}