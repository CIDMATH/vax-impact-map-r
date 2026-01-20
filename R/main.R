# Function to run all project code
# --------------------------------------------------------------------------
main <- function() {
  
  ## Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  ## Set file location relative to current project
  # --------------------------------------------------------------------------
  here::i_am("R/main.R")
  
  ## Source and run code
  # --------------------------------------------------------------------------
  
  ## Get and process data - only needs to be run when refreshing data
  # read_path_get_and_process_data_r <- here("R/get_and_process_data.R")
  # source(read_path_get_and_process_data_r)
  # get_and_process_data()
  
  ## Run the model
  read_path_run_model_r <- here("R/run_model.R")
  source(read_path_run_model_r)
  run_model()
  
}

main()