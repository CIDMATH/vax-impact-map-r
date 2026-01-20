# Calculate disease burden based on calibrated cases
# --------------------------------------------------------------------------

calculate_disease_burden <- function(df) {
  
  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))
  
  # Set file location relative to current project
  # --------------------------------------------------------------------------
  here::i_am("R/calculate_disease_burden.R")
  
  # Using cases, determine morbidity, mortality, and economic burden
  # --------------------------------------------------------------------------
  df$hospitalizations <- df$cases * df$proportion_hospitalized_given_infected
  df$hospitalizations_per_100k <- df$hospitalizations / df$age_group_population * 100000
  
  df$deaths <- df$cases * df$death_rate
  df$deaths_per_100k <- df$deaths / df$age_group_population * 100000
  
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