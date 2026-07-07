# Create function curate_vaccine_coverage_targets for building a disease-level
# reference dataset of vaccine coverage targets in the `data` folder
# --------------------------------------------------------------------------
#
# Purpose
# --------------------------------------------------------------------------
# Produces a compact, disease-granularity dataset intended for the
# vaximpactmap rebuild. One row per disease (matching the diseases present in
# the curated model output) with:
#   - disease                                : disease name (as in the curated model output)
#   - age_group_text                         : human-readable age label, mirroring the
#                                              app.R "Children Ages <Title Case age_group>" text
#   - vaccine_coverage_target_percent        : reference coverage target (see logic below)
#   - vaccine_coverage_target_percent_source : URL documenting where the target came from
#
# Target logic
# --------------------------------------------------------------------------
# There are only explicit Healthy People 2030 (HP2030) vaccination targets for
# MMR and DTaP. For this reference dataset we use:
#   - MMR            -> 95% : HP2030 IID-04, "Maintain vaccination coverage
#                            level of 2 doses of MMR vaccine for children in
#                            kindergarten" (95%).
#   - Everything else -> 90% : WHO Immunization Agenda 2030 (IA2030) reference
#                            coverage level.
# The MMR row is NOT currently in the curated model output, but the lookup
# below is written so that IF MMR (or DTaP, etc.) is ever added as a modeled
# disease, it will automatically pick up the correct target and source. All
# diseases not named in `target_lookup` fall back to the 90% default.
# --------------------------------------------------------------------------

curate_vaccine_coverage_targets <- function() {

  # Install & load required libraries
  # --------------------------------------------------------------------------
  packages <- c("tidyverse","here")
  install.packages(setdiff(packages, rownames(installed.packages())))
  invisible(lapply(packages, library, character.only = TRUE))

  # Set file location relative to current project
  # --------------------------------------------------------------------------
  suppressMessages(here::i_am("R/curate_vaccine_coverage_targets.R"))
  print("IV. curate_vaccine_coverage_targets.R")

  # Reference source URLs
  # --------------------------------------------------------------------------
  source_hp2030_mmr_kindergarten <- "https://odphp.health.gov/healthypeople/objectives-and-data/browse-objectives/vaccination/maintain-vaccination-coverage-level-2-doses-mmr-vaccine-children-kindergarten-iid-04"
  source_who_ia2030             <- "https://www.who.int/teams/immunization-vaccines-and-biologicals/strategies/ia2030/explaining-the-immunization-agenda-2030"

  # Default target applied to any disease not explicitly listed below
  # --------------------------------------------------------------------------
  default_target_percent <- 90
  default_target_source  <- source_who_ia2030

  # Disease-specific overrides. Add rows here as new diseases with explicit
  # HP2030 (or other) targets are introduced. Matching is case-insensitive on
  # `disease`. MMR is included ahead of time so the app is MMR-ready.
  # --------------------------------------------------------------------------
  target_lookup <- tibble::tribble(
    ~disease, ~vaccine_coverage_target_percent, ~vaccine_coverage_target_percent_source,
    "MMR",    95,                               source_hp2030_mmr_kindergarten
  )

  # Read the curated model output from the `data` folder
  # --------------------------------------------------------------------------
  read_path_rds <- here("data/vax_impact_map_model_output_curated.rds")
  df <- readRDS(read_path_rds)

  # Build the disease-granularity dataset
  # --------------------------------------------------------------------------
  targets <- df %>%
    # One row per disease / age_group combination present in the model output
    distinct(disease, age_group) %>%
    # Human-readable age label, mirroring app.R's age_group_info text
    mutate(age_group_text = paste0("Children Ages ", tools::toTitleCase(age_group))) %>%
    # Attach coverage target + source via case-insensitive lookup, defaulting
    # to the WHO IA2030 90% reference for any disease not in target_lookup
    mutate(.join_key = tolower(disease)) %>%
    left_join(
      target_lookup %>% mutate(.join_key = tolower(disease)) %>% select(-disease),
      by = ".join_key"
    ) %>%
    mutate(
      vaccine_coverage_target_percent = dplyr::coalesce(
        vaccine_coverage_target_percent, default_target_percent
      ),
      vaccine_coverage_target_percent_source = dplyr::coalesce(
        vaccine_coverage_target_percent_source, default_target_source
      )
    ) %>%
    select(
      disease,
      age_group_text,
      vaccine_coverage_target_percent,
      vaccine_coverage_target_percent_source
    ) %>%
    arrange(disease)

  # Write data as a csv to the project `data/csv` folder
  # --------------------------------------------------------------------------
  write_path_csv <- here("data/csv/vax_impact_map_vaccine_coverage_targets.csv")
  write.csv(targets, file = write_path_csv, row.names = FALSE)

  # Write data as a rds to the project `data` folder
  # --------------------------------------------------------------------------
  write_path_rds <- here("data/vax_impact_map_vaccine_coverage_targets.rds")
  saveRDS(targets, file = write_path_rds)

  # Return the dataset invisibly for interactive use
  # --------------------------------------------------------------------------
  invisible(targets)

}
