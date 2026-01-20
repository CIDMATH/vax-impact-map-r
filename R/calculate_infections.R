# Calculate infections based on endemic equilibrium annual incidence 
# --------------------------------------------------------------------------

calculate_infections <- function(df) {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  here::i_am("R/calculate_infections.R")
  
  ## Calculate modeled number of infections
  # --------------------------------------------------------------------------
  df$infections <- df$endemic_equilibrium_incidence_rate_annual * df$age_group_population
  df$infections_per_100k <- df$infections / df$age_group_population * 100000
  
  return(df)
  
}