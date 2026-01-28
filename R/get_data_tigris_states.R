# Function that gets tigris state data
# --------------------------------------------------------------------------
get_data_tigris_states <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidycensus","tidyverse","here","tigris","sf")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/get_data_tigris_states.R"))
  print("--4. get_data_tigris_states.R")
  
  # Create function get_data_tigris_states to get and save tigris state data
  # --------------------------------------------------------------------------
  
  # Get US state geometry for mapping
  df <- tigris::states(cb = TRUE, resolution = "20m") %>%
    tigris::shift_geometry() %>% filter(!NAME=='Puerto Rico')
  
  # Write data as a rds called tigris_states.rds to the project `data-raw` folder
  write_path_rds <- here("data-raw/tigris_states.rds")
  saveRDS(df, file = write_path_rds)
  
  # Message specifying where data was written
  # print(paste0("Saved state data to ",write_path_rds))
  
  # Write data as a csv called tigris_states.csv to the project `data-raw` folder
  write_path_csv <- here("data-raw/csv/tigris_states.csv")
  write.csv(df, file = write_path_csv)
  
  # Message specifying where data was written
  # print(paste0("Saved state data to ",write_path_csv))
  
}