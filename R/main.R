# ----------------------main.R----------------------------------------------

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
  read_path_get_and_process_data_r <- here("R/get_and_process_data.R")
  source(read_path_get_and_process_data_r)
  get_and_process_data()
  
  ## Compile model input data
  read_path_compile_model_input_data_r <- here("R/compile_model_input_data.R")
  source(read_path_compile_model_input_data_r)
  compile_model_input_data()
  
  
  
}

main()