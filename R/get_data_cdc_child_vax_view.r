# Create function get_data_cdc_child_vax_view for retrieving data from CDC Child Vax View
# --------------------------------------------------------------------------
get_data_cdc_child_vax_view <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  here::i_am("R/get_data_cdc_child_vax_view.R")
  
  # Create function get_data_cdc_child_vax_view by reading the CSV from the data.cdc.gov Socrata API
  # See: https://data.cdc.gov/Child-Vaccinations/Vaccination-Coverage-among-Young-Children-0-35-Mon/fhky-rtsk/about_data
  # --------------------------------------------------------------------------
  
  df <- read.csv('https://data.cdc.gov/api/views/fhky-rtsk/rows.csv?accessType=DOWNLOAD&api_foundry=true')
  
  # Write data as a rds called cdc_child_vax_view.rds to the project `data-raw` folder
  write_path_rds <- here("data-raw/cdc_child_vax_view.rds")
  saveRDS(df, file = write_path_rds)
  
  # Message specifying where data was written
  print(paste0("Saved state data to ",write_path_rds))
  
  # Write data as a csv called cdc_child_vax_view.csv to the project `data-raw` folder
  write_path_csv <- here("data-raw/csv/cdc_child_vax_view.csv")
  write.csv(df, file = write_path_csv)
  
  # Message specifying where data was written
  print(paste0("Saved state data to ",write_path_csv))
  
}