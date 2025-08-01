#' Calculate query distribution
#'
#' Calculated distribution of a query from a prior or
#' posterior distribution of parameters
#'
#'
#' @inheritParams CausalQueries_internal_inherit_params
#' @param parameters A vector or list of vectors of real numbers in [0,1].
#'   A true parameter vector to be used instead of parameters attached to
#'   the model in case  \code{using} specifies \code{parameters}
#' @param using A character. Whether to use priors, posteriors or parameters
#' @param queries A vector of strings or list of strings specifying queries
#'   on potential outcomes such as "Y[X=1] - Y[X=0]".
#'   Queries can also indicate conditioning sets by placing second queries after a colon:
#'   "Y[X=1] - Y[X=0] :|: X == 1 & Y == 1". Note a ':|:' is used rather than the traditional
#'   conditioning marker '|' to avoid confusion with logical operators.
#' @param given  A character vector specifying given conditions for each query.
#'   A 'given' is a quoted expression that evaluates to logical statement.
#'   \code{given} allows the query to be conditioned on either observed
#'   or counterfactural distributions. A value of TRUE is interpreted as no conditioning.
#'   A given statement can alternatively be provided after a colon in the query statement.
#' @param join_by A character. The logical operator joining expanded types
#'   when \code{query} contains wildcard (\code{.}). Can take values
#'   \code{"&"} (logical AND) or \code{"|"} (logical OR). When restriction
#'   contains wildcard (\code{.}) and \code{join_by} is not specified, it
#'   defaults to \code{"|"}, otherwise it defaults to \code{NULL}.
#' @param n_draws An integer. Number of draws.rm
#' @param case_level Logical. If TRUE estimates the probability of
#'   the query for a case.
#' @param query alias for queries
#' @return A data frame where columns contain draws from the distribution
#'   of the potential outcomes specified in \code{query}
#' @importFrom stats sd weighted.mean
#' @export
#' @examples
#' model <- make_model("X -> Y") |>
#'          set_parameters(c(.5, .5, .1, .2, .3, .4))
#'  \donttest{
#'  # simple  queries
#'  query_distribution(model, query = "(Y[X=1] > Y[X=0])", using = "priors") |>
#'    head()
#'
#'  # multiple  queries
#'  query_distribution(model,
#'      query = list(PE = "(Y[X=1] > Y[X=0])", NE = "(Y[X=1] < Y[X=0])"),
#'      using = "priors")|>
#'    head()
#'
#'  # multiple queries and givens, with ':' to identify conditioning distributions
#'  query_distribution(model,
#'    query = list(POC = "(Y[X=1] > Y[X=0]) :|: X == 1 & Y == 1",
#'                 Q = "(Y[X=1] < Y[X=0]) :|: (Y[X=1] <= Y[X=0])"),
#'    using = "priors")|>
#'    head()
#'
#'  # multiple queries and givens, using 'given' argument
#'  query_distribution(model,
#'    query = list("(Y[X=1] > Y[X=0])", "(Y[X=1] < Y[X=0])"),
#'    given = list("Y==1", "(Y[X=1] <= Y[X=0])"),
#'    using = "priors")|>
#'    head()
#'
#'  # linear queries
#'  query_distribution(model, query = "(Y[X=1] - Y[X=0])")
#'
#'
#'  # Linear query conditional on potential outcomes
#'  query_distribution(model, query = "(Y[X=1] - Y[X=0]) :|: Y[X=1]==0")
#'
#'  # Use join_by to amend query interpretation
#'  query_distribution(model, query = "(Y[X=.] == 1)", join_by = "&")
#'
#'  # Probability of causation query
#'  query_distribution(model,
#'     query = "(Y[X=1] > Y[X=0])",
#'     given = "X==1 & Y==1",
#'     using = "priors")  |> head()
#'
#'  # Case level probability of causation query
#'  query_distribution(model,
#'     query = "(Y[X=1] > Y[X=0])",
#'     given = "X==1 & Y==1",
#'     case_level = TRUE,
#'     using = "priors")
#'
#'  # Query posterior
#'  update_model(model, make_data(model, n = 3)) |>
#'  query_distribution(query = "(Y[X=1] - Y[X=0])", using = "posteriors") |>
#'  head()
#'
#'  # Case level queries provide the inference for a case, which is a scalar
#'  # The case level query *updates* on the given information
#'  # For instance, here we have a model for which we are quite sure that X
#'  # causes Y but we do not know whether it works through two positive effects
#'  # or two negative effects. Thus we do not know if M=0 would suggest an
#'  # effect or no effect
#'
#'  set.seed(1)
#'  model <-
#'    make_model("X -> M -> Y") |>
#'    update_model(data.frame(X = rep(0:1, 8), Y = rep(0:1, 8)), iter = 10000)
#'
#'  Q <- "Y[X=1] > Y[X=0]"
#'  G <- "X==1 & Y==1 & M==1"
#'  QG <- "(Y[X=1] > Y[X=0]) & (X==1 & Y==1 & M==1)"
#'
#'  # In this case these are very different:
#'  query_distribution(model, Q, given = G, using = "posteriors")[[1]] |> mean()
#'  query_distribution(model, Q, given = G, using = "posteriors",
#'    case_level = TRUE)
#'
#'  # These are equivalent:
#'  # 1. Case level query via function
#'  query_distribution(model, Q, given = G,
#'     using = "posteriors", case_level = TRUE)
#'
#'  # 2. Case level query by hand using Bayes' rule
#'  query_distribution(
#'      model,
#'      list(QG = QG, G = G),
#'      using = "posteriors") |>
#'     dplyr::summarize(mean(QG)/mean(G))
#'
#' }
#'
query_distribution <- function(model,
                               queries = NULL,
                               given = NULL,
                               using  = "parameters",
                               parameters = NULL,
                               n_draws = 4000,
                               join_by = "|",
                               case_level = FALSE,
                               query = NULL) {
  ## check arguments
  if (is(model, "causal_model")) {
    model <- list(model)
  }

  if (length(model) > 1) {
    stop(
      paste(
        "Please specify a single causal model in the `model` argument.",
        "You can pass a `causal_model` object directly or wrap it in a `list`."
      )
    )
  }

  if (!is.null(query)) {
    queries <- query
  }

  # ensure that givens are only specified via given argument or :|: in query
  given_in_statement <- vapply(queries, function(i) grepl(":\\|:", i), logical(1))
  if (!is.null(given) && any(given_in_statement)) {
    stop(
      paste(
        "please specify givens either via the `given` argument or via `:|:`",
        "within your query statements; not both."
      )
    )
  }

  if ((!is.null(parameters)) && (!is.list(parameters))) {
    parameters <- list(parameters)
  }

  if ((!is.null(parameters)) && (length(parameters) > 1)) {
    stop("Please only specify one set of parameters for your model.")
  }

  args_checked <- check_args(
    model = model,
    using = unlist(using),
    given = unlist(given),
    queries = queries,
    case_level = case_level,
    fun = "query_distribution"
  )

  given <- args_checked$given
  using <- args_checked$using

  ## generate required data structures
  # generate model names
  model_names <- "model_1"
  names(model) <- model_names

  if (!is.null(parameters)) {
    names(parameters) <- model_names
  }

  # generate outcome realisations
  realisations <-
    lapply(model, function(m)
      realise_outcomes(model = m))
  names(realisations) <- model_names

  # prevent bugs from query helpers
  given <- vapply(given, as.character, character(1))
  q_names <- names(queries)
  queries <- vapply(queries, as.character, character(1))
  names(queries) <- q_names

  jobs <- lapply(model_names, function(m) {
    data.frame(
      model_names = m,
      using = unlist(using),
      given = unlist(given),
      queries = unlist(queries),
      case_level = unlist(case_level),
      stringsAsFactors = FALSE
    )
  }) |>
    dplyr::bind_rows()

  # alter jobs if givens are specified in queries
  if(any(given_in_statement)) {
    for (q in queries) {
      split_query_statement <- deparse_given(q)
      jobs[jobs$queries == q, "given"] <- split_query_statement$given
      jobs[jobs$queries == q, "queries"] <- split_query_statement$query
    }
  }

  # only generate necessary data structures for unique subsets of jobs
  # handle givens
  given_types <- queries_to_types(
    jobs = jobs,
    model = model,
    query_col = "given",
    realisations = realisations
  )
  # handle queries
  query_types <- queries_to_types(
    jobs = jobs,
    model = model,
    query_col = "queries",
    realisations = realisations
  )
  # handle type distributions
  type_posteriors <- get_type_posteriors(
    jobs = jobs,
    model = model,
    n_draws = n_draws,
    parameters = parameters
  )
  # get estimands
  estimands <- get_estimands(
    jobs = jobs,
    given_types = given_types,
    query_types = query_types,
    type_posteriors = type_posteriors
  ) |>
    as.data.frame()

  # prepare output
  if (!is.null(names(queries))) {
    colnames(estimands) <- make.unique(names(queries), sep = "_")
  } else {
    query_names <- jobs$queries
    given_names <- jobs$given
    given_names <- vapply(given_names, function(g) {
      if (g == "ALL") {
        gn <- ""
      } else {
        gn <- paste(" :|: ", g, sep = "")
      }
      return(gn)
    }, character(1))
    colnames(estimands) <-
      make.unique(paste(query_names, given_names, sep = ""), sep = "_")
  }

  return(estimands)
}


#' Generate data frame for batches of causal queries
#'
#' Calculated from a parameter vector, from a prior or
#' from a posterior distribution.
#'
#' Queries can condition on observed or counterfactual quantities.
#' Nested or "complex" counterfactual queries of the form
#' \code{Y[X=1, M[X=0]]} are allowed.
#'
#' @inheritParams CausalQueries_internal_inherit_params
#' @param queries A vector of strings or list of strings specifying queries
#'   on potential outcomes such as "Y[X=1] - Y[X=0]".
#'   Queries can also indicate conditioning sets by placing second queries after a colon:
#'   "Y[X=1] - Y[X=0] :|: X == 1 & Y == 1". Note a colon, ':|:' is used rather than the traditional
#'   conditioning marker '|' to avoid confusion with logical operators.
#' @param given  A character vector specifying given conditions for each query.
#'   A 'given' is a quoted expression that evaluates to logical statement.
#'   \code{given} allows the query to be conditioned on either observed
#'   or counterfactual distributions. A value of TRUE is interpreted as no conditioning.
#'   A given statement can alternatively be provided after a colon in the query statement.
#' @param using A vector or list of strings. Whether to use priors,
#'   posteriors or parameters.
#' @param stats Functions to be applied to the query distribution.
#'   If NULL, defaults to mean, standard deviation,
#'   and 95\% confidence interval. Functions should return a single numeric
#'   value.
#' @param n_draws An integer. Number of draws.
#' @param expand_grid Logical. If \code{TRUE} then all combinations of
#'   provided lists are examined. If not then each list is cycled through
#'   separately. Defaults to FALSE.
#' @param case_level Logical. If TRUE estimates the probability of the
#'   query for a case.
#' @param query alias for queries
#' @param cred size of the credible interval ranging between 0 and 100
#' @param labels labels for queries: if provided labels should have
#'   the length of the combinations of requests
#' @return An object of class \code{model_query}. A data frame with possible
#'   columns: model, query, given, using, case_level, mean, sd, cred.low, cred.high.
#'   Further columns are generated as specified in \code{stats}.
#' @export
#' @examples
#' model <- make_model("X -> Y")
#' query_model(model, "Y[X=1] - Y[X = 0]", using = "priors")
#' query_model(model, "Y[X=1] - Y[X = 0] :|: X==1 & Y==1", using = "priors")
#' query_model(model,
#'   list("Y[X=1] - Y[X = 0]",
#'        "Y[X=1] - Y[X = 0] :|: X==1 & Y==1"),
#'   using = "priors")
#' query_model(model, "Y[X=1] > Y[X = 0]", using = "parameters")
#' query_model(model, "Y[X=1] > Y[X = 0]", using = c("priors", "parameters"))
#' \donttest{
#'
#' # `expand_grid= TRUE` requests the Cartesian product of arguments
#'
#' models <- list(
#'  M1 = make_model("X -> Y"),
#'  M2 = make_model("X -> Y") |>
#'    set_restrictions("Y[X=1] < Y[X=0]")
#'  )
#'
#' # No expansion: lists should be equal length
#' query_model(
#'   models,
#'   query = list(ATE = "Y[X=1] - Y[X=0]",
#'                Share_positive = "Y[X=1] > Y[X=0]"),
#'   given = c(TRUE,  "Y==1 & X==1"),
#'   using = c("parameters", "priors"),
#'   expand_grid = FALSE)
#'
#' # Expansion when query and given arguments coupled
#' query_model(
#'   models,
#'   query = list(ATE = "Y[X=1] - Y[X=0]",
#'                Share_positive = "Y[X=1] > Y[X=0] :|: Y==1 & X==1"),
#'   using = c("parameters", "priors"),
#'   expand_grid = TRUE)
#'
#' # Expands over query and given argument when these are not coupled
#' query_model(
#'   models,
#'   query = list(ATE = "Y[X=1] - Y[X=0]",
#'                Share_positive = "Y[X=1] > Y[X=0]"),
#'   given = c(TRUE,  "Y==1 & X==1"),
#'   using = c("parameters", "priors"),
#'   expand_grid = TRUE)
#'
#' # An example of a custom statistic: uncertainty of token causation
#' f <- function(x) mean(x)*(1-mean(x))
#'
#' query_model(
#'   model,
#'   using = list( "parameters", "priors"),
#'   query = "Y[X=1] > Y[X=0]",
#'   stats = c(mean = mean, sd = sd, token_variance = f))
#'}

query_model <- function(model,
                        queries = NULL,
                        given = NULL,
                        using = list("parameters"),
                        parameters = NULL,
                        stats = NULL,
                        n_draws = 4000,
                        expand_grid = NULL,
                        case_level = FALSE,
                        query = NULL,
                        cred = 95,
                        labels = NULL) {
  # handle global variables

  func_call <- match.call()
  date <- date()

  query_name <- NULL

  # if single model passed to function place it in a list
  if (is(model, "causal_model")) {
    model <- list(model)
  }

  ## check arguments
  if (!is.null(query) & !is.null(queries)) {
    stop("Please provide either queries or query, not both.")
  }

  if (!is.null(query)) {
    queries <- query
  }

  # ensure that givens are only specified via given argument or :|: in query
  given_in_statement <- vapply(queries, function(i) grepl(":\\|:", i), logical(1))
  if (!is.null(given) && any(given_in_statement)) {
    stop(
      paste(
        "please specify givens either via the `given` argument or via `:|:`",
        "within your query statements; not both."
      )
    )
  }

  if ((!is.null(parameters)) && (!is.list(parameters))) {
    stop("Please specify parameters as a list of parameter vectors.")
  }

  if ((!is.null(parameters)) &&
      (length(model) != length(parameters))) {
    stop("Please specify parameters for each model.")
  }

  # check that parameters are specified for each model + named
  args_checked <- check_args(
    model = model,
    using = unlist(using),
    given = unlist(given),
    queries = queries,
    case_level = case_level,
    fun = "query_model"
  )

  given <- args_checked$given
  using <- args_checked$using

  ## generate required data structures
  # generate model names
  if (!is.null(names(model))) {
    model_names <- names(model)
  } else {
    model_names <- paste("model", seq_along(model), sep = "_")
    names(model) <- model_names
  }

  if (!is.null(parameters)) {
    names(parameters) <- model_names
  }

  # query names
  queries <- unlist(queries)
  query_names <- names(queries)
  no_query_names <- is.null(query_names)

  if(no_query_names) {
    query_names <- paste("Q", seq_along(queries), sep = "")
    names(queries) <- query_names
  }

  # realise_outcomes
  realisations <- lapply(model, function(m) {
    realise_outcomes(model = m)
  })

  names(realisations) <- model_names

  # prevent bugs from query helpers
  given <- vapply(given, as.character, character(1))
  queries <- vapply(queries, as.character, character(1))

  # Guess expand_grid
  differing_lengths <-
    list(queries, model_names, unname(unlist(using)), unname(unlist(given)) ,
      query_names, unname(unlist(case_level))) |> sapply(length) |>
    unique() |> setdiff(c(0,1))

  if(is.null(expand_grid)) expand_grid <- length(differing_lengths) > 1

  if(!expand_grid & length(differing_lengths) > 1)
    stop("If expand_grid = FALSE, then supplied arguments should be of equal length (or of length 1)")

  # create jobs
  if (expand_grid) {
    jobs <- expand.grid(
      model_names,
      unname(unlist(using)),
      unname(unlist(given)),
      query_names,
      unname(unlist(case_level)),
      stringsAsFactors = FALSE
    )
    names(jobs) <-
      c("model_names",
        "using",
        "given",
        "query_name",
        "case_level")
  } else {
    jobs <- lapply(model_names, function(m) {
      data.frame(
        model_names = m,
        using = unname(unlist(using)),
        given = unname(unlist(given)),
        query_name = query_names,
        case_level = unname(unlist(case_level)),
        stringsAsFactors = FALSE
      )
    }) |>
      dplyr::bind_rows()
  }

  # merge queries onto jobs
  jobs$queries <- queries[jobs$query_name]

  # alter jobs if givens are specified in queries
  if(any(given_in_statement)) {
    for (q in queries) {
      split_query_statement <- deparse_given(q)
      jobs[jobs$queries == q, "given"] <- split_query_statement$given
      jobs[jobs$queries == q, "queries"] <- split_query_statement$query
    }
  }

  # set query names
  if (no_query_names) {
    jobs <- jobs |>
      mutate(
      query_name = queries,
      query_name = ifelse(given != "ALL", paste(queries, ":|:", given), query_name))

  }


  # only generate necessary data structures for unique subsets of jobs
  # handle givens
  given_types <- queries_to_types(
    jobs = jobs,
    model = model,
    query_col = "given",
    realisations = realisations
  )
  # handle queries
  query_types <- queries_to_types(
    jobs = jobs,
    model = model,
    query_col = "queries",
    realisations = realisations
  )
  # handle type distributions
  type_posteriors <- get_type_posteriors(
    jobs = jobs,
    model = model,
    n_draws = n_draws,
    parameters = parameters
  )

  # get estimands
  estimands <- get_estimands(
    jobs = jobs,
    given_types = given_types,
    query_types = query_types,
    type_posteriors = type_posteriors
  )

  # compute statistics
  if (is.null(stats)) {
    if (!is.null(parameters)) {
      stats <- c(mean = mean)
    } else {
      cred <- pmax(pmin(cred[1], 100), 0)
      stats <- c(
        mean = mean,
        sd = sd,
        cred.low = function(x)
          unname(stats::quantile(
            x, probs = ((100 - cred) / 200), na.rm = TRUE
          )),
        cred.high = function(x)
          unname(stats::quantile(
            x, probs = (1 - (100 - cred) / 200), na.rm = TRUE
          ))
      )
    }
  }

  estimands <-
    lapply(estimands, function(e) {
      vapply(stats, function(s) {
        s(e)
      }, numeric(1)) |>
        t()
    })

  estimands <- as.data.frame(do.call(rbind, estimands))

  # prepare output
  query_id <- jobs |>
    dplyr::select(label= query_name, model_names, queries, given, using, case_level) |>
    dplyr::mutate(given = ifelse(given == "ALL", "-", given))

  colnames(query_id) <-
    c("label", "model", "query", "given", "using", "case_level")

  estimands <- cbind(query_id, estimands)

  if (length(model) == 1) {
    estimands <- estimands[, colnames(estimands) != "model"]
  }


  if (!is.null(labels)){
    if(length(labels) != nrow(estimands)) {
      message(paste("labels have been provided but are of incorrect length:", nrow(estimands), "labels required"))
      labels <- NULL
    }
    if(length(labels) != length(unique(labels))) {
      message(paste("labels are not unique (now ignored)"))
      labels <- NULL
    }

    }

  if (!is.null(labels))
    estimands <- estimands |> mutate(label = labels) |> relocate(label)

  class(estimands) <- c("model_query", "data.frame")

  attr(estimands, "call") <- func_call
  attr(estimands, "date") <- date

  # Add warnings from any models
  warnings <- lapply(model, function(m) grab(m,  "stan_warnings"))

  attr(estimands, "stan_warnings") <-

    if(any(sapply(warnings, function(xx) !is.null(xx) && xx != ""))){
      sapply(seq_along(warnings), function(i)
        paste0("\nModel ", i, ' warnings:\n', warnings[[i]], '\n'))
    } else {
      ""
    }


  return(estimands)
}



#' helper to check arguments
#'
#' @param model passed from parent function
#' @param using passed from parent function
#' @param given passed from parent function
#' @param queries passed from parent function
#' @param fun string specifying the name of the parent function
#' @return list of altered arguments
#' @keywords internal
#' @noRd

check_args <-
  function(model,
           using,
           given,
           queries,
           case_level,
           fun) {

    lapply(model, function(m) {
      is_a_model(m)
    })

    using[using == "posterior"] <- "posteriors"
    using[using == "prior"] <- "priors"

    if ((fun == "query_distribution") && is.null(given)) {
      given <- rep("ALL", length(queries))
    }

    if ((fun == "query_model") && is.null(given)) {
      given <- "ALL"
    }

    if (is.logical(given)) {
      given <- as.character(given)
    }

  if (!is.null(given) && !is.character(given)) {
      stop(
      paste(
        "`given` must be a vector of strings specifying given",
        "statements or '', 'All', 'ALL', 'all', 'None', 'none', 'NONE' or",
        "'TRUE' for no givens."
      )
    )
  }

  if ((fun == "query_distribution") &&
      (!is.null(given)) &&
      (length(given) != length(queries))) {
    stop(
      paste(
        "You must specify a given for each query. Use ''",
        ", 'All', 'ALL', 'all', 'None', 'none', 'NONE' or 'TRUE'",
        "to indicate no given."
      )
    )
  }

  if (any(!using %in% c("priors", "posteriors", "parameters"))) {
    stop(paste(
      "`using` may only take values:",
      "`priors`, `posteriors`, or `parameters`"
    ))
  }

  given[given %in% c('',
                     'All',
                     'ALL',
                     'all',
                     'None',
                     'none',
                     'NONE',
                     'TRUE')] <- "ALL"

    if ((fun == "query_distribution") && (length(case_level) > 1)) {
      stop("You can only specify a single value for the `case_level` argument.")
    }

    return(list(given = given, using = using))
  }


#' helper to get types from queries
#'
#' @param jobs a data frame of argument combinations
#' @param model a list of models
#' @param query_col string specifying the name of the column in jobs
#'   holding queries to be evaluated
#' @param realisations list of data frame outputs from calls
#'   to \code{realise_outcomes}
#' @return jobs data frame with a nested column of
#'   \code{map_query_to_nodal_type} outputs
#' @keywords internal
#' @noRd

queries_to_types <- function(jobs,
                             model,
                             query_col,
                             realisations) {
  unique_jobs <-
    dplyr::distinct(jobs, (!!as.name("model_names")), (!!as.name(query_col)))
  types <- vector(mode = "list", length = nrow(unique_jobs))

  for (i in seq_len(nrow(unique_jobs))) {
    model_i <- unique_jobs[i, "model_names"]

    if ((query_col == "given") &&
        (unique_jobs[i, query_col] == "ALL")) {
      types[[i]] <- TRUE
    } else {
      types[[i]] <- map_query_to_causal_type(
        model = model[[model_i]],
        query = unique_jobs[i, query_col],
        eval_var = realisations[[model_i]])$types
    }
  }
  unique_jobs$type_vec <- types
  return(unique_jobs)
}

#' helper to get type distributions
#'
#' @param jobs data frame of argument combinations
#' @param model a list of models
#' @param n_draws integer specifying number of draws from prior distribution
#' @param parameters optional list of parameter vectors
#' @return jobs data frame with a nested column of type distributions
#' @keywords internal

get_type_posteriors <- function(jobs,
                                   model,
                                   n_draws,
                                   parameters = NULL) {
  unique_jobs <-
    dplyr::distinct(jobs, (!!as.name("model_names")), (!!as.name("using")))
  distributions <- vector(mode = "list", length = nrow(unique_jobs))

  if (is.null(parameters)) {
    parameters <- list()
  }

  for (i in seq_len(nrow(unique_jobs))) {
    model_i <- unique_jobs[i, "model_names"]
    using_i <- unique_jobs[i, "using"]

    if ((using_i == "parameters") &&
        is.null(parameters[[model_i]])) {
      parameters[[model_i]] <- get_parameters(model[[model_i]])
    }

    if ((using_i == "priors") &&
        is.null(model[[model_i]]$prior_distribution)) {
      model[[model_i]] <-
        set_prior_distribution(model[[model_i]], n_draws = n_draws)
    }

    if (using_i == "parameters") {
      distributions[[i]] <-
        get_type_prob(model = model[[model_i]],
                      parameters = parameters[[model_i]])
    } else {
      distributions[[i]] <-
        get_type_prob_multiple(model = model[[model_i]],
                               using = using_i,
                               P = model[[model_i]]$P)
    }
  }
  unique_jobs$type_posterior <- distributions
  return(unique_jobs)
}

#' helper to get estimands
#'
#' @param jobs a data frame of argument combinations
#' @param given_types output from \code{queries_to_types}
#' @param query_types output from \code{queries_to_types}
#' @param type_posteriors output from \code{get_type_posteriors}
#' @return a list of estimands
#' @keywords internal

get_estimands <- function(jobs,
                            given_types,
                            query_types,
                            type_posteriors) {
    estimands <- vector(mode = "list", length = nrow(jobs))

    for (i in seq_len(nrow(jobs))) {
      model_name_i <- jobs[i, "model_names"]
      using_i <- jobs[i, "using"]
      given_i <- jobs[i, "given"]
      queries_i <- jobs[i, "queries"]
      case_level_i <- jobs[i, "case_level"]

      x <-
        query_types[(query_types$model_names == model_name_i &
                       query_types$queries == queries_i), "type_vec"][[1]]
      given <-
        given_types[(given_types$model_names == model_name_i &
                       given_types$given == given_i), "type_vec"][[1]]
      type_posterior <-
        type_posteriors[(
          type_posteriors$model_names == model_name_i &
            type_posteriors$using == using_i
        ), "type_posterior"][[1]]
      x <- x[given]

      if (all(!given)) {
        estimand <- NA
        message("No units given. `NA` estimand.")
      } else {
        # using parameters
        if (using_i == "parameters") {
          # always case level when using parameters
          estimand <-
            sum(x * type_posterior[given]) / sum(type_posterior[given])
        }
        # using priors or posteriors
        if (using_i != "parameters") {
          # population level
          if (!case_level_i) {
            estimand <-
              (x %*% type_posterior[given, , drop = FALSE]) /
              apply(type_posterior[given, , drop = FALSE], 2, sum)
          }
          # case level
          if (case_level_i) {
            estimand <-
              mean(x %*% type_posterior[given, , drop = FALSE]) /
              mean(apply(type_posterior[given, , drop = FALSE], 2, sum))
          }
        }
      }
      estimands[[i]] <- as.vector(unlist(estimand))
    }

    return(estimands)
  }

#' helper to separate query and givens in query statement
#' @keywords internal
#' @noRd

deparse_given <- function(query) {
  # check for malformed query + given syntax
  if (gregexpr(":\\|", query)[[1]] |> length() > 1) {
    stop(
      paste(
        "Found multiple `:|:` in your query statement.",
        "Please separate givens from queries via a single `:|:`."
      )
    )
  }

  split <- trimws(strsplit(query, ":\\|:")[[1]])
  query <- split[1]
  given <- split[2]

  if(is.na(given)) {
    given <- "ALL"
  }

  return(list(query = query, given = given))
}


#' S3 method for query plotting
#' @keywords internal
#' @noRd

plot_query <- function(model_query) {

    if(any("posteriors" %in% model_query$using)){
      if(any(attr(model_query, "stan_warnings") != "")) {
        cat("Note: warnings passed from rstan during updating:\n")
        cat(attr(model_query, "stan_warnings"))
        cat("\n")
      }}


    # create bindings
    query <- case_level <- using <- cred.low <- cred.high <- NULL
    # adjust this value to control the amount of dodge
    dodge_width <- 0.2

    if (!("model" %in% names(model_query)))
      model_query$model <- "Causal Queries"

    if(!("label" %in% names(model_query)))  {
    model_query <- model_query |>
      mutate(
        given = gsub("==", "=", given),
        label = ifelse(given != "-", paste(query, "\ngiven ", given), query)
      )
    }
    # add 'case' to case level query labels
    model_query <- model_query |>
      mutate(label = ifelse(case_level, paste(label, "(case)"), label))

    # given formatting
    model_query <- model_query |> mutate(label = gsub(":\\|:", "\ngiven", label))

    model_query |>
      ggplot(aes(mean, label, color = using)) +
      geom_point(position = position_dodge(width = dodge_width)) +
      geom_errorbarh(aes(
        xmin = cred.low,
        xmax = cred.high,
        height = .2
      ),
      position = position_dodge(width = dodge_width)) +
      theme_bw() + facet_wrap( ~ model) + xlab("value") + ylab("")
  }

#' @export
plot.model_query <- function(x, ...) {
    plot_query(x,...)
  }


