# ----------------------get_data_model_input_parameters.R-------------------

get_data_model_input_parameters <- function() {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  here::i_am("R/get_data_model_input_parameters.R")
  
  # Create function get_data_model_input_parameters by reading the model_input_parameters CSV from the `data-raw` folder
  # --------------------------------------------------------------------------
  
  # Get model input parameters from the model_input_parameters CSV in the `data-raw` folder
  read_path_csv <- here("data-raw/csv/model_input_parameters.csv")
  df <- read.csv(read_path_csv)
  
  # Write data as a rds called model_input_parameters.rds to the project `data-raw` folder
  write_path_rds <- here("data-raw/model_input_parameters.rds")
  saveRDS(df, file = write_path_rds)
  
  # Message specifying where data was written
  print(paste0("Saved state data to ",write_path_rds))
  
}