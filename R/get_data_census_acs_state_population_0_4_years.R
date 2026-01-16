# ----------------------get_data_census_acs_state_population_0_4_years.R----

# Install & load required libraries
# --------------------------------------------------------------------------
packages <- c("tidycensus","tidyverse","here")
install.packages(setdiff(packages, rownames(installed.packages())))
invisible(lapply(packages, library, character.only = TRUE))

# Set file location relative to current project
# --------------------------------------------------------------------------
here::i_am("R/get_data_census_acs_state_population_0_4_years.R")

# Create function get_data_census_acs_state_population_0_4_years by calling the census ACS API from tidycensus
# --------------------------------------------------------------------------
get_data_census_acs_state_population_0_4_years <- function() {
  
  # Get state data from Census ACS
  df_state <- get_acs(geography = "state", 
                variables = c("B01001_003E", # Male population age 0-4y
                              "B01001_027E"), # Female population age 0-4y
                year = 2023, 
                geometry = FALSE) %>% 
    group_by(GEOID, NAME) %>%
    summarise(population_0_4_years = sum(estimate)) %>%
    rename(state_fips_code = GEOID,
           state_name = NAME)
  
  # Get national data from Census ACS
  df_nation <- get_acs(geography = "us", 
                variables = c("B01001_003E", # Male population age 0-4y
                              "B01001_027E"), # Female population age 0-4y
                year = 2023, 
                geometry = FALSE) %>% 
    group_by(GEOID, NAME) %>%
    summarise(population_0_4_years = sum(estimate)) %>%
    rename(state_fips_code = GEOID,
           state_name = NAME)
  
  # Union state and nation data
  df <- union(df_state,df_nation)
  
  # Write data as a rds called census_acs_state_population_0_4_years.rds to the project `data-raw` folder
  write_path_rds <- here("data-raw/census_acs_state_population_0_4_years.rds")
  saveRDS(df, file = write_path_rds)
  
  # Message specifying where data was written
  print(paste0("Saved state data to ",write_path_rds))
  
  # Write data as a csv called census_acs_state_population_0_4_years.csv to the project `data-raw` folder
  write_path_csv <- here("data-raw/csv/census_acs_state_population_0_4_years.csv")
  write.csv(df, file = write_path_csv)
  
  # Message specifying where data was written
  print(paste0("Saved state data to ",write_path_csv))
  
}