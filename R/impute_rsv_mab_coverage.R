# Statistical imputation of state-level infant RSV monoclonal antibody coverage
# using coverage for five routinely recommended childhood vaccines.
#
# Inputs (percent units, 0-100):
#   cdc_nirsevimab_coverage.csv
#   cdc_child_vax_view_rotavirus.csv
#   cdc_school_vax_view_dtap.csv
#   cdc_child_vax_view_pcv.csv
#   cdc_school_vax_view_varicella.csv
#   cdc_child_vax_view_hib.csv
#
# Primary model:
#   Seven-nearest-neighbor (KNN) imputation based on standardized coverage for
#   rotavirus, DTaP, PCV, varicella, and Hib. For each state without observed
#   mAb coverage, the estimate is the mean observed mAb coverage among the seven
#   reporting states with the most similar five-vaccine coverage profiles.
#
# Benchmark models:
#   1. Mean observed state coverage
#   2. Seven-nearest-neighbor imputation
#   3. Rotavirus-only regression
#   4. Composite five-vaccine coverage regression
#   5. Ordinary five-predictor regression
#   6. Five-predictor ridge regression
#
# Missing predictor values are replaced by the training-state mean within each
# cross-validation fold. This currently matters for Montana, which is absent
# from the supplied DTaP and varicella files. Missing mAb outcomes are never
# used to fit or tune the model.
#
# Outputs:
#   rsv_mab_coverage_imputed.csv
#   rsv_mab_model_performance.csv
#   rsv_mab_cross_validated_predictions.csv
#   rsv_mab_imputation_diagnostics.pdf (optional)
#
# The final output retains observed coverage when available and uses model
# predictions only for states with missing mAb coverage. The United States row
# is retained from the input as an aggregate among reporting jurisdictions and
# is excluded from model fitting.


impute_rsv_mab_coverage <- function(
    input_dir = file.path(getwd(), "data-raw", "csv"),
    output_dir = input_dir,
    final_model = c("knn7", "best_cv", "ridge5"),
    make_plots = TRUE,
    seed = 20260804L) {

  final_model <- match.arg(final_model)
  set.seed(seed)

  files <- c(
    mab = "cdc_nirsevimab_coverage.csv",
    rotavirus = "cdc_child_vax_view_rotavirus.csv",
    dtap = "cdc_school_vax_view_dtap.csv",
    pcv = "cdc_child_vax_view_pcv.csv",
    varicella = "cdc_school_vax_view_varicella.csv",
    hib = "cdc_child_vax_view_hib.csv"
  )

  # file.path() can drop the names carried by `files`. Preserve them
  # explicitly because those names are used below to identify each dataset.
  input_paths <- file.path(input_dir, unname(files))
  names(input_paths) <- names(files)
  missing_files <- input_paths[!file.exists(input_paths)]
  if (length(missing_files) > 0L) {
    stop(
      "Required input file(s) not found:\n",
      paste0("  - ", missing_files, collapse = "\n"),
      call. = FALSE
    )
  }

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  states_dc <- c(state.name, "District of Columbia")
  predictor_names <- c("rotavirus", "dtap", "pcv", "varicella", "hib")
  knn_neighbors <- 7L
  lambda_grid <- 10^seq(-4, 4, length.out = 81L)

  # ------------------------------------------------------------------------
  # Data import and validation
  # ------------------------------------------------------------------------

  parse_coverage <- function(x) {
    x <- trimws(as.character(x))
    x[x %in% c("", "NA", "N/A", "Not Submitted", "Not submitted", "Suppressed")] <- NA_character_
    x <- gsub("%", "", x, fixed = TRUE)
    x <- gsub(",", "", x, fixed = TRUE)
    out <- suppressWarnings(as.numeric(x))

    observed <- out[is.finite(out)]
    if (length(observed) > 0L && max(observed) <= 1.000001) {
      out <- 100 * out
    }
    out
  }

  read_coverage <- function(path, value_name) {
    dat <- read.csv(
      path,
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = c("", "NA", "N/A")
    )

    required <- c("state_name", "vaccine_coverage_estimate")
    absent <- setdiff(required, names(dat))
    if (length(absent) > 0L) {
      stop(
        basename(path), " is missing required column(s): ",
        paste(absent, collapse = ", "),
        call. = FALSE
      )
    }

    dat$state_name <- trimws(as.character(dat$state_name))
    dat[[value_name]] <- parse_coverage(dat$vaccine_coverage_estimate)
    dat <- dat[, c("state_name", value_name), drop = FALSE]
    dat <- dat[!is.na(dat$state_name) & nzchar(dat$state_name), , drop = FALSE]

    if (anyDuplicated(dat$state_name)) {
      duplicates <- unique(dat$state_name[duplicated(dat$state_name)])
      stop(
        basename(path), " contains duplicate geography rows: ",
        paste(duplicates, collapse = ", "),
        call. = FALSE
      )
    }

    bad <- !is.na(dat[[value_name]]) &
      (dat[[value_name]] < 0 | dat[[value_name]] > 100)
    if (any(bad)) {
      stop(
        basename(path), " contains coverage outside 0-100 for: ",
        paste(dat$state_name[bad], collapse = ", "),
        call. = FALSE
      )
    }

    dat
  }

  imported <- Map(
    function(path, value_name) read_coverage(path, value_name),
    input_paths,
    names(files)
  )
  # Map/mapply naming can vary with its arguments, so restore the expected
  # names explicitly rather than relying on implicit propagation.
  names(imported) <- names(files)

  # Begin with a fixed 50-state + DC geography so territories and national
  # aggregates cannot enter the statistical model accidentally.
  model_data <- data.frame(
    state_name = states_dc,
    stringsAsFactors = FALSE
  )

  for (nm in names(imported)) {
    model_data <- merge(
      model_data,
      imported[[nm]],
      by = "state_name",
      all.x = TRUE,
      sort = FALSE
    )
    model_data <- model_data[
      match(states_dc, model_data$state_name),
      ,
      drop = FALSE
    ]
  }

  mab_input <- imported[["mab"]]
  if (is.null(mab_input)) {
    stop("The imported mAb dataset could not be identified.", call. = FALSE)
  }
  us_row <- mab_input[mab_input$state_name == "United States", , drop = FALSE]
  us_aggregate <- if (nrow(us_row) == 1L) us_row$mab[1L] else NA_real_

  observed_index <- which(!is.na(model_data$mab))
  if (length(observed_index) < 10L) {
    stop(
      "Only ", length(observed_index),
      " states have observed mAb coverage. At least 10 are required.",
      call. = FALSE
    )
  }

  x_all <- as.matrix(model_data[, predictor_names, drop = FALSE])
  storage.mode(x_all) <- "double"
  y_all <- model_data$mab

  x_observed <- x_all[observed_index, , drop = FALSE]
  y_observed <- y_all[observed_index]
  state_observed <- model_data$state_name[observed_index]

  # ------------------------------------------------------------------------
  # Modeling utilities
  # ------------------------------------------------------------------------

  clamp_percent <- function(x) pmin(pmax(x, 0), 100)

  to_logit <- function(percent) {
    p <- pmin(pmax(percent / 100, 0.001), 0.999)
    qlogis(p)
  }

  from_logit <- function(x) 100 * plogis(x)

  standardize_fold <- function(x_train, x_new) {
    means <- colMeans(x_train, na.rm = TRUE)
    sds <- apply(x_train, 2L, sd, na.rm = TRUE)

    if (any(!is.finite(means))) {
      bad <- colnames(x_train)[!is.finite(means)]
      stop(
        "Predictor(s) contain no observed training values: ",
        paste(bad, collapse = ", "),
        call. = FALSE
      )
    }

    sds[!is.finite(sds) | sds == 0] <- 1

    train_scaled <- sweep(x_train, 2L, means, FUN = "-")
    train_scaled <- sweep(train_scaled, 2L, sds, FUN = "/")
    new_scaled <- sweep(x_new, 2L, means, FUN = "-")
    new_scaled <- sweep(new_scaled, 2L, sds, FUN = "/")

    # Mean imputation after standardization is represented by zero.
    train_scaled[is.na(train_scaled)] <- 0
    new_scaled[is.na(new_scaled)] <- 0

    list(
      train = train_scaled,
      new = new_scaled,
      means = means,
      sds = sds
    )
  }

  solve_coefficients <- function(x, y_logit, lambda = 0) {
    design <- cbind("(Intercept)" = 1, x)
    penalty <- diag(c(0, rep(lambda, ncol(x))))
    lhs <- crossprod(design) + penalty
    rhs <- crossprod(design, y_logit)

    coefficients <- tryCatch(
      solve(lhs, rhs),
      error = function(e) qr.solve(lhs, rhs, tol = 1e-10)
    )
    as.numeric(coefficients)
  }

  predict_coefficients <- function(x, coefficients) {
    design <- cbind("(Intercept)" = 1, x)
    as.numeric(design %*% coefficients)
  }

  ridge_loo_errors <- function(x, y_percent, lambda) {
    n <- nrow(x)
    predictions <- rep(NA_real_, n)

    for (i in seq_len(n)) {
      training <- setdiff(seq_len(n), i)
      scaled <- standardize_fold(
        x[training, , drop = FALSE],
        x[i, , drop = FALSE]
      )
      coefficients <- solve_coefficients(
        scaled$train,
        to_logit(y_percent[training]),
        lambda = lambda
      )
      predictions[i] <- from_logit(
        predict_coefficients(scaled$new, coefficients)
      )
    }

    abs(predictions - y_percent)
  }

  select_ridge_lambda <- function(x, y_percent, grid = lambda_grid) {
    error_matrix <- vapply(
      grid,
      function(lambda) ridge_loo_errors(x, y_percent, lambda),
      numeric(nrow(x))
    )
    mean_absolute_error <- colMeans(error_matrix)

    # In the event of a numerical tie, choose the larger penalty and therefore
    # the more conservative, more strongly shrunk model.
    minimum <- min(mean_absolute_error)
    candidates <- which(mean_absolute_error <= minimum + 1e-10)
    selected <- max(candidates)

    list(
      lambda = grid[selected],
      index = selected,
      mae = mean_absolute_error[selected],
      grid = grid,
      grid_mae = mean_absolute_error
    )
  }

  predict_candidate <- function(model, x_train, y_train, x_new,
                                ridge_lambda = NULL) {
    if (model == "mean") {
      return(rep(mean(y_train), nrow(x_new)))
    }

    scaled <- standardize_fold(x_train, x_new)

    if (model == "knn7") {
      number_of_neighbors <- min(knn_neighbors, nrow(scaled$train))

      predictions <- apply(scaled$new, 1L, function(new_row) {
        distances <- sqrt(rowSums(
          sweep(scaled$train, 2L, new_row, FUN = "-")^2
        ))
        nearest <- order(distances)[seq_len(number_of_neighbors)]
        mean(y_train[nearest])
      })

      return(as.numeric(predictions))
    }

    y_logit <- to_logit(y_train)

    if (model == "rotavirus") {
      coefficients <- solve_coefficients(
        scaled$train[, "rotavirus", drop = FALSE],
        y_logit,
        lambda = 0
      )
      return(from_logit(predict_coefficients(
        scaled$new[, "rotavirus", drop = FALSE],
        coefficients
      )))
    }

    if (model == "composite") {
      train_composite <- matrix(rowMeans(scaled$train), ncol = 1L)
      new_composite <- matrix(rowMeans(scaled$new), ncol = 1L)
      coefficients <- solve_coefficients(
        train_composite,
        y_logit,
        lambda = 0
      )
      return(from_logit(predict_coefficients(
        new_composite,
        coefficients
      )))
    }

    if (model == "ols5") {
      coefficients <- solve_coefficients(scaled$train, y_logit, lambda = 0)
      return(from_logit(predict_coefficients(scaled$new, coefficients)))
    }

    if (model == "ridge5") {
      if (is.null(ridge_lambda)) {
        ridge_lambda <- select_ridge_lambda(x_train, y_train)$lambda
      }
      coefficients <- solve_coefficients(
        scaled$train,
        y_logit,
        lambda = ridge_lambda
      )
      return(from_logit(predict_coefficients(scaled$new, coefficients)))
    }

    stop("Unknown model: ", model, call. = FALSE)
  }

  # ------------------------------------------------------------------------
  # Nested leave-one-state-out cross-validation
  # ------------------------------------------------------------------------

  candidate_models <- c(
    "mean", "knn7", "rotavirus", "composite", "ols5", "ridge5"
  )
  cv_predictions <- matrix(
    NA_real_,
    nrow = length(y_observed),
    ncol = length(candidate_models),
    dimnames = list(state_observed, candidate_models)
  )
  outer_ridge_lambda <- rep(NA_real_, length(y_observed))

  for (i in seq_along(y_observed)) {
    training <- setdiff(seq_along(y_observed), i)
    x_train <- x_observed[training, , drop = FALSE]
    y_train <- y_observed[training]
    x_test <- x_observed[i, , drop = FALSE]

    cv_predictions[i, "mean"] <- predict_candidate(
      "mean", x_train, y_train, x_test
    )
    cv_predictions[i, "knn7"] <- predict_candidate(
      "knn7", x_train, y_train, x_test
    )
    cv_predictions[i, "rotavirus"] <- predict_candidate(
      "rotavirus", x_train, y_train, x_test
    )
    cv_predictions[i, "composite"] <- predict_candidate(
      "composite", x_train, y_train, x_test
    )
    cv_predictions[i, "ols5"] <- predict_candidate(
      "ols5", x_train, y_train, x_test
    )

    inner_tuning <- select_ridge_lambda(x_train, y_train)
    outer_ridge_lambda[i] <- inner_tuning$lambda
    cv_predictions[i, "ridge5"] <- predict_candidate(
      "ridge5",
      x_train,
      y_train,
      x_test,
      ridge_lambda = inner_tuning$lambda
    )
  }

  performance <- do.call(
    rbind,
    lapply(candidate_models, function(model) {
      prediction <- cv_predictions[, model]
      residual <- prediction - y_observed
      total_sum_squares <- sum((y_observed - mean(y_observed))^2)
      r_squared <- if (total_sum_squares > 0) {
        1 - sum(residual^2) / total_sum_squares
      } else {
        NA_real_
      }

      data.frame(
        model = model,
        n_states = length(y_observed),
        mae = mean(abs(residual)),
        rmse = sqrt(mean(residual^2)),
        cross_validated_r_squared = r_squared,
        stringsAsFactors = FALSE
      )
    })
  )
  performance <- performance[order(performance$mae), , drop = FALSE]
  rownames(performance) <- NULL

  best_cv_model <- performance$model[1L]
  model_used <- if (final_model == "best_cv") best_cv_model else final_model

  mean_mae <- performance$mae[performance$model == "mean"]
  ridge_mae <- performance$mae[performance$model == "ridge5"]
  if (model_used == "ridge5" &&
      length(mean_mae) == 1L && length(ridge_mae) == 1L &&
      ridge_mae >= mean_mae) {
    warning(
      sprintf(
        paste0(
          "The five-vaccine ridge model did not outperform the mean benchmark ",
          "in LOSO-CV (ridge MAE %.2f vs mean MAE %.2f percentage points). ",
          "Predictions will therefore be strongly shrunk toward the observed-state mean."
        ),
        ridge_mae,
        mean_mae
      ),
      call. = FALSE
    )
  }

  knn_mae <- performance$mae[performance$model == "knn7"]
  if (model_used == "knn7" &&
      length(mean_mae) == 1L && length(knn_mae) == 1L &&
      knn_mae >= mean_mae) {
    warning(
      sprintf(
        paste0(
          "The seven-nearest-neighbor model did not outperform the mean ",
          "benchmark in LOSO-CV (KNN MAE %.2f vs mean MAE %.2f percentage ",
          "points)."
        ),
        knn_mae,
        mean_mae
      ),
      call. = FALSE
    )
  }

  # ------------------------------------------------------------------------
  # Final model and predictions for all states
  # ------------------------------------------------------------------------

  full_ridge_tuning <- select_ridge_lambda(x_observed, y_observed)
  final_ridge_lambda <- full_ridge_tuning$lambda

  if (model_used == "ridge5") {
    model_predictions <- predict_candidate(
      "ridge5",
      x_observed,
      y_observed,
      x_all,
      ridge_lambda = final_ridge_lambda
    )
  } else {
    model_predictions <- predict_candidate(
      model_used,
      x_observed,
      y_observed,
      x_all
    )
  }
  model_predictions <- clamp_percent(model_predictions)

  selected_cv_prediction <- cv_predictions[, model_used]
  cv_residual <- y_observed - selected_cv_prediction

  # Empirical LOSO-CV residual intervals. These reflect state-level prediction
  # error, not binomial sampling error in the IIS coverage estimates.
  residual_quantiles <- quantile(
    cv_residual,
    probs = c(0.025, 0.10, 0.90, 0.975),
    na.rm = TRUE,
    names = FALSE,
    type = 8
  )

  observed_flag <- !is.na(model_data$mab)
  predictor_imputed_flag <- apply(is.na(x_all), 1L, any)

  output <- data.frame(
    vaccine = "nirsevimab",
    state_name = model_data$state_name,
    observed_coverage_estimate = model_data$mab,
    predicted_coverage_estimate = model_predictions,
    vaccine_coverage_estimate = ifelse(
      observed_flag,
      model_data$mab,
      model_predictions
    ),
    coverage_source = ifelse(observed_flag, "observed", "predicted"),
    prediction_lower_80 = ifelse(
      observed_flag,
      NA_real_,
      clamp_percent(model_predictions + residual_quantiles[2L])
    ),
    prediction_upper_80 = ifelse(
      observed_flag,
      NA_real_,
      clamp_percent(model_predictions + residual_quantiles[3L])
    ),
    prediction_lower_95 = ifelse(
      observed_flag,
      NA_real_,
      clamp_percent(model_predictions + residual_quantiles[1L])
    ),
    prediction_upper_95 = ifelse(
      observed_flag,
      NA_real_,
      clamp_percent(model_predictions + residual_quantiles[4L])
    ),
    prediction_model = ifelse(observed_flag, NA_character_, model_used),
    predictor_values_imputed = predictor_imputed_flag,
    stringsAsFactors = FALSE
  )

  # Retain the national aggregate already constructed from reporting
  # jurisdictions. It is not used for training or state-level imputation.
  output <- rbind(
    output,
    data.frame(
      vaccine = "nirsevimab",
      state_name = "United States",
      observed_coverage_estimate = us_aggregate,
      predicted_coverage_estimate = NA_real_,
      vaccine_coverage_estimate = us_aggregate,
      coverage_source = "reporting_states_aggregate",
      prediction_lower_80 = NA_real_,
      prediction_upper_80 = NA_real_,
      prediction_lower_95 = NA_real_,
      prediction_upper_95 = NA_real_,
      prediction_model = NA_character_,
      predictor_values_imputed = NA,
      stringsAsFactors = FALSE
    )
  )

  cv_output <- data.frame(
    state_name = state_observed,
    observed_coverage_estimate = y_observed,
    cv_predictions,
    ridge_lambda_selected_in_outer_fold = outer_ridge_lambda,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  performance$selected_by_cross_validation <-
    performance$model == best_cv_model
  performance$used_for_imputation <- performance$model == model_used
  performance$final_ridge_lambda <- ifelse(
    performance$model == "ridge5",
    final_ridge_lambda,
    NA_real_
  )
  performance$knn_neighbors <- ifelse(
    performance$model == "knn7",
    knn_neighbors,
    NA_integer_
  )

  output_file <- file.path(output_dir, "rsv_mab_coverage_imputed.csv")
  performance_file <- file.path(output_dir, "rsv_mab_model_performance.csv")
  cv_file <- file.path(output_dir, "rsv_mab_cross_validated_predictions.csv")

  write.csv(output, output_file, row.names = FALSE, na = "NA")
  write.csv(performance, performance_file, row.names = FALSE, na = "NA")
  write.csv(cv_output, cv_file, row.names = FALSE, na = "NA")

  saveRDS(
    output,
    file.path(output_dir, "rsv_mab_coverage_imputed.rds")
  )

  # ------------------------------------------------------------------------
  # Diagnostic plots
  # ------------------------------------------------------------------------

  if (isTRUE(make_plots)) {
    plot_file <- file.path(output_dir, "rsv_mab_imputation_diagnostics.pdf")
    grDevices::pdf(plot_file, width = 10, height = 8)
    old_par <- par(no.readonly = TRUE)
    on.exit({
      par(old_par)
      grDevices::dev.off()
    }, add = TRUE)

    par(mfrow = c(2, 2), mar = c(5, 5, 3, 1))

    ordered_performance <- performance[order(performance$mae), ]
    barplot(
      ordered_performance$mae,
      names.arg = ordered_performance$model,
      las = 2,
      col = ifelse(
        ordered_performance$used_for_imputation,
        "#2E74B5",
        "#BFC7D1"
      ),
      ylab = "LOSO-CV MAE (percentage points)",
      main = "Out-of-sample model performance"
    )

    state_abbreviation <- state.abb[match(state_observed, state.name)]
    state_abbreviation[state_observed == "District of Columbia"] <- "DC"
    plot(
      y_observed,
      selected_cv_prediction,
      xlim = range(c(y_observed, selected_cv_prediction)),
      ylim = range(c(y_observed, selected_cv_prediction)),
      xlab = "Observed mAb coverage (%)",
      ylab = "Cross-validated prediction (%)",
      main = paste("LOSO-CV:", model_used),
      pch = 19,
      col = "#2E74B5"
    )
    abline(0, 1, lty = 2, col = "#666666")
    text(
      y_observed,
      selected_cv_prediction,
      labels = state_abbreviation,
      pos = 3,
      cex = 0.7
    )

    correlations <- cor(
      cbind(mab = y_observed, x_observed),
      use = "pairwise.complete.obs"
    )
    image(
      seq_len(ncol(correlations)),
      seq_len(nrow(correlations)),
      t(correlations[nrow(correlations):1, ]),
      axes = FALSE,
      col = colorRampPalette(c("#B2182B", "white", "#2166AC"))(101),
      zlim = c(-1, 1),
      xlab = "",
      ylab = "",
      main = "Pairwise correlations"
    )
    axis(1, at = seq_len(ncol(correlations)), labels = colnames(correlations), las = 2)
    axis(
      2,
      at = seq_len(nrow(correlations)),
      labels = rev(rownames(correlations)),
      las = 2
    )

    hist(
      cv_residual,
      breaks = "FD",
      col = "#DCE6F1",
      border = "white",
      xlab = "Observed minus cross-validated prediction",
      main = "Cross-validated residuals"
    )
    abline(v = 0, lty = 2, col = "#666666")
  }

  message("Observed states used for model fitting: ", length(y_observed))
  message("Best LOSO-CV model: ", best_cv_model)
  message("Model used for imputation: ", model_used)
  message("KNN neighbors: ", knn_neighbors)
  if (model_used == "ridge5") {
    message("Final ridge lambda: ", signif(final_ridge_lambda, 5))
  }
  message("Predicted states: ", sum(output$coverage_source == "predicted"))
  message("Output written to: ", output_file)

  invisible(list(
    coverage = output,
    performance = performance,
    cross_validated_predictions = cv_output,
    model_used = model_used,
    best_cv_model = best_cv_model,
    knn_neighbors = knn_neighbors,
    final_ridge_lambda = final_ridge_lambda
  ))
}


# Running this file with Rscript executes the default pipeline paths. Sourcing
# the file defines the function without running it, so the caller can supply
# alternative input and output directories.
if (sys.nframe() == 0L) {
  impute_rsv_mab_coverage()
}