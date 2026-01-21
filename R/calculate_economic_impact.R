# Calculate economic impact based on disease burden
# --------------------------------------------------------------------------

calculate_economic_impact <- function(df) {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/calculate_disease_burden.R"))
  print("-G. calculate_economic_impact.R")
  
  # Using disease burden, calculate economic burden
  # --------------------------------------------------------------------------
  df$workdays_lost <- df$cases * df$duration_sick_days
  df$workdays_lost_per_100k <- df$workdays_lost / df$age_group_population * 100000
  
  df$productivity_cost <- df$workdays_lost * df$cost_wage_daily
  df$productivity_cost_per_100k <- df$productivity_cost / df$age_group_population * 100000
  
  df$hospitalization_cost <- df$hospitalizations * df$duration_hospitalized_days * df$cost_hospitalization_daily
  df$hospitalization_cost_per_100k <- df$hospitalization_cost / df$age_group_population * 100000
  
  df$total_cost <- df$productivity_cost + df$hospitalization_cost
  df$total_cost_per_100k <- df$total_cost / df$age_group_population * 100000
  
  return(df)
  
}