
#' Produces the possible permutations of a set of nodes
#'
#' @param max A vector of integers. The maximum value of an integer value
#'   starting at 0. Defaults to 1. The number of permutation is defined
#'   by \code{max}'s length
#' @keywords internal
#' @return A \code{matrix} of permutations
#' @importFrom rlang exprs

perm <- function(max = rep(1, 2)) {

  grid <- vector(mode = "list", length = length(max))

  for(i in seq_along(grid)) {
    grid[[i]] <- rlang::exprs(0:!!max[i])[[1]]
  }

    x <- do.call(expand.grid, grid)

    colnames(x) <- NULL

    return(x)
}

#' Get string between two regular expression patterns
#'
#' Returns a substring enclosed by two regular expression patterns.
#' By default returns the name of the arguments being indexed by
#' squared brackets (\code{[]}) in a string containing an expression.
#'
#' @param x A character string.
#' @param left A character string. Regular expression to serve as look ahead.
#' @param right A character string. Regular expression to
#'   serve as a look behind.
#' @param rm_left An integer. Number of bites after left-side match to remove
#'   from result. Defaults to -1.
#' @param rm_right An integer. Number of bites after right-side match to remove
#'   from result. Defaults to 0.
#' @return A character vector.
#' @noRd
#' @keywords internal
#' @examples
#' a <- '(XX[Y=0] == 1) > (XX[Y=1] == 0)'
#' CausalQueries:::st_within(a)
#' b <- '(XXX[[Y=0]] == 1 + XXX[[Y=1]] == 0)'
#' CausalQueries:::st_within(b)

st_within <- function(x,
                      left = "[^_[:^punct:]]|\\b",
                      right = "\\[",
                      rm_left = 0,
                      rm_right = -1) {

    if (!is.character(x)) {
      stop("`x` must be a string.")
    }

    puncts <- gregexpr(left, x, perl = TRUE)[[1]]
    stops <- gregexpr(right, x, perl = TRUE)[[1]]

    # only index the first of the same boundary
    # when there are consecutive ones (eg. '[[')
    consec_brackets <- diff(stops)
    if (any(consec_brackets == 1)) {
        remov <- which(consec_brackets == 1) + 1
        stops <- stops[-remov]
    }

    # find the closest punctuation or space
    starts <- vapply(stops, function(s) {
      dif <- s - puncts
      dif <- dif[dif > 0]
      ifelse(length(dif) == 0,
             ret <- NA,
             ret <- puncts[which(dif == min(dif))])
      return(ret)
    }, numeric(1))

    drop <- is.na(starts) | is.na(stops)
    vapply(seq_along(starts), function(i) {
      if (!drop[i]) {
        substr(x, starts[i] + rm_left, stops[i] + rm_right)
      } else {
        as.character(NA)
      }
    }, character(1))
}

#' Recursive substitution
#'
#' Applies \code{gsub()} from multiple patterns to multiple
#' replacements with 1:1 mapping.
#' @return Returns multiple expression with substituted elements
#' @noRd
#' @keywords internal
#' @param x A character vector.
#' @param pattern_vector A character vector.
#' @param replacement_vector A character vector.
#' @param ... Options passed onto \code{gsub()} call.

gsub_many <- function(x,
                      pattern_vector,
                      replacement_vector,
                      ...) {
    if (!identical(length(pattern_vector), length(replacement_vector))) {
      stop("pattern and replacement vectors must be the same length")
    }

    for (i in seq_along(pattern_vector)) {
        x <- gsub(pattern_vector[i], replacement_vector[i], x, ...)
    }
    return(x)
}

#' Clean condition
#'
#' Takes a string specifying condition and returns properly spaced string.
#' @noRd
#' @keywords internal
#' @return A properly spaced string.
#' @param condition A character string. Condition that refers to a unique
#'   position (possible outcome) in a nodal type.

clean_condition <- function(condition) {
    spliced <- strsplit(condition, split = "")[[1]]
    spaces <- grepl("[[:space:]]", spliced, perl = TRUE)
    paste(spliced[!spaces], collapse = " ")
}

#' Interpret or find position in nodal type
#'
#' Interprets the position of one or more digits (specified by \code{position})
#' in a nodal type. Alternatively returns nodal type digit positions that
#' correspond to one or more given \code{condition}.
#' @inheritParams CausalQueries_internal_inherit_params
#' @param condition A vector of characters. Strings specifying the child node,
#'   followed by '|' (given) and the values of its parent nodes in \code{model}.
#' @param position A named list of integers. The name is the name of the child
#'   node in \code{model}, and its value a vector of digit positions in that
#'   node's nodal type to be interpreted. See `Details`.
#' @param nodes A vector of names of nodes. Can be used to limit interpretation to
#'   selected nodes. By default limited to non root nodes.
#' @return A named \code{list} with interpretation of positions of
#'   the digits in a nodal type
#' @details A node for a child node X with \code{k} parents has a nodal type
#'   represented by X followed by \code{2^k} digits. Argument \code{position}
#'   allows user to interpret the meaning of one or more digit positions in any
#'   nodal type. For example \code{position = list(X = 1:3)} will return the
#'   interpretation of the first three digits in causal types for X.
#'   Argument \code{condition} allows users to query the digit position in the
#'   nodal type by providing instead the values of the parent nodes of a given
#'   child. For example, \code{condition = 'X | Z=0 & R=1'} returns the digit
#'   position that corresponds to values X takes when Z = 0 and R = 1.
#' @examples
#' model <- make_model('R -> X; Z -> X; X -> Y')
#' # Return interpretation of all digit positions of all nodes
#' interpret_type(model)
#' # Example using digit position
#' interpret_type(model, position = list(X = c(3,4), Y = 1))
#' interpret_type(model, position = list(R = 1))
#' # Example using condition
#' interpret_type(model, condition = c('X | Z=0 & R=1', 'X | Z=0 & R=0'))
#' # Example using node names
#' interpret_type(model, nodes = c("Y", "R"))
#' @export
#'

interpret_type <- function(model,
                           condition = NULL,
                           position = NULL,
                           nodes = model$parents_df[!model$parents_df$root, 1]) {

  # Checks

   if(!is.null(position) && !all(names(position) %in% nodes )){
     message("Specify position variables from among requested nodes only")
     position <- NULL
   }

    if (!is.null(condition) & !is.null(position)) {
      stop("Must specify either `condition` or `nodal_position`, but not both.")
    }

  if(is.null(nodes)){
    nodes <- model$nodes
  }

    parents <- get_parents(model)
    types <- lapply(lapply(parents, length), function(l) perm(rep(1, l)))

    if (is.null(position)) {
      position <-
        lapply(types, function(i)
          ifelse(length(i) == 0, return(NA), return(seq_len(nrow(i)))))
    } else {
      if (!all(names(position) %in% names(types))) {
        stop("One or more names in `position` not found in model.")
      }
    }

    interpret <- lapply(seq_along(position), function(i) {
      positions <- position[[i]]
      type <- types[[names(position)[i]]]
      pos_elements <- type[positions,]

      if (!all(is.na(positions))) {
        interpret <-
          vapply(seq_len(nrow(pos_elements)), function(row)
            paste0(parents[[names(position)[i]]],
                   " = ", pos_elements[row,], collapse = " & "),
            character(1))
        interpret <-
          paste0(paste0(c(" ", names(position)[i], " = * if "), collapse = ""), interpret)

        # Create '-*--'-type representations
        asterisks <- rep("-", nrow(type))
        asterisks_ <- vapply(positions, function(s) {
          if (s < length(asterisks)) {
            if (s == 1) {
              paste0(c("*", asterisks[(s + 1):length(asterisks)]),
                     collapse = "")
            } else {
              paste0(c(asterisks[1:(s - 1)], "*",
                       asterisks[(s + 1):length(asterisks)]),
                     collapse = "")
            }
          } else {
            paste0(c(asterisks[1:(s - 1)], "*"), collapse = "")
          }
        }, character(1))
        display <- paste0(asterisks_)
      } else {
        # Root nodes
        display <- "*"
        interpret <- paste0(names(position)[i], " = *")

      }
      data.frame(
        index = display,
        interpretation = interpret,
        stringsAsFactors = FALSE
      )
    })

    names(interpret) <- names(position)

    if (!is.null(condition)) {
      conditions <- parse_conditions(condition, nodes)

      # Initialize a list to store filtered data frames
      filtered_list <- list()

      for (lhs in names(conditions)) {
        rhs_patterns <- conditions[[lhs]]
        pattern_1 <- paste(rhs_patterns, collapse = "|")
        pattern_2 <- interpret[[lhs]][[2]]
        # Filter rows where the column named lhs contains any RHS pattern
        accept <- sapply(pattern_2, function(x) any(grepl(pattern_1, x)))
        interpret[[lhs]] <- interpret[[lhs]][accept,]
      }

      # filtered_list now contains filtered data.frames by lhs key
    }

    return(interpret[nodes[nodes %in% names(position)]])
}

# converts "X | Z=0 & R=1" into $X [1] "R = 1 & Z = 0" (ordered and standard)
# parse_conditions(condition = c('X | Z=0 & R=1', 'X | Z=0 & R=0', 'R | Z=1'))
# CausalQueries:::parse_conditions(condition = c('X | Z=0 & R=1', 'X | Z=0 & R=0', 'R | Z=1'), nodes = c("X", "R", "Z"))

parse_conditions <- function(condition, nodes) {
  # Split each string at the first "|"
  split_conditions <- strsplit(condition, "\\|")

  # Trim whitespace
  split_conditions <- lapply(split_conditions, function(x) trimws(x))

  # Extract LHS and RHS
  lhs <- sapply(split_conditions, function(x) x[1])
  rhs <- sapply(split_conditions, function(x) x[2])

  x <- lapply(rhs, function(x) {

  parts <- strsplit(x, "&")[[1]]
  parts <- trimws(parts)

  # Extract variable, operator, and value
  parsed <- lapply(parts, function(part) {
    matches <- regmatches(part, regexec("^\\s*(\\w+)\\s*(=)\\s*(\\S+)\\s*$", part))[[1]]
    if (length(matches) != 4) stop(paste("Cannot parse:", part))
    list(var = matches[2], op = matches[3], val = matches[4])
  })

  # Reorder based on nodes
  parsed <- parsed[order(match(sapply(parsed, `[[`, "var"), nodes))]

  # Reformat with spacing
  reformatted <- sapply(parsed, function(x) paste0(x$var, " ", x$op, " ", x$val))

  # Join with properly spaced '&'
  paste(reformatted, collapse = " & ")[[1]]
  })

  # Combine RHS values into a named list by LHS
  split(x |> unlist(), lhs)
}

#' Expand wildcard
#'
#' Expand statement containing wildcard
#'
#' @inheritParams CausalQueries_internal_inherit_params
#' @param to_expand A character vector of length 1L.
#' @param verbose Logical. Whether to print expanded query on the console.
#' @return A character string with the expanded expression.
#'   Wildcard '.' is replaced by 0 and 1.
#' @importFrom rlang expr
#' @examples
#'
#' # Position of parentheses matters for type of expansion
#' # In the "global expansion" versions of the entire statement are joined
#' expand_wildcard('(Y[X=1, M=.] > Y[X=1, M=.])')
#' # In the "local expansion" versions of indicated parts are joined
#' expand_wildcard('(Y[X=1, M=.]) > (Y[X=1, M=.])')
#'
#' # If parentheses are missing global expansion used.
#' expand_wildcard('Y[X=1, M=.] > Y[X=1, M=.]')
#'
#' # Expressions not requiring expansion are allowed
#' expand_wildcard('(Y[X=1])')
#' @noRd
#' @keywords internal

expand_wildcard <- function(to_expand,
                            join_by = "|",
                            verbose = TRUE) {
    orig <- st_within(to_expand, left = "\\(", right = "\\)", rm_left = 1)

    if(is.na(orig[1])) {
      message(
        paste("No parentheses indicated. Global expansion assumed.",
              "See expand_wildcard")
      )
      orig <- to_expand
    }

    skeleton <- gsub_many(to_expand,
                          orig,
                          paste0("%expand%", seq_along(orig)),
                          fixed = TRUE)
    expand_it <- grepl("\\.", orig)

    expanded_types <- lapply(seq_along(orig), function(i) {
        if (!expand_it[i])
            return(orig[i]) else {
            exp_types <- strsplit(orig[i], ".", fixed = TRUE)[[1]]
            a <- gregexpr("\\w{1}\\s*(?=(=\\s*\\.){1})", orig[i], perl = TRUE)
            matcha <- trimws(unlist(regmatches(orig[i], a)))
            rep_n <- vapply(unique(matcha), function(e) sum(matcha == e),
                            numeric(1))
            n_types <- length(unique(matcha))
            grid <- replicate(n_types, expr(c(0, 1)))
            type_values <- do.call(expand.grid, grid)
            colnames(type_values) <- unique(matcha)

            apply(type_values, 1, function(s) {
                to_sub <- paste0(colnames(type_values), "(\\s)*=(\\s)*$")
                subbed <- gsub_many(exp_types,
                                    to_sub,
                                    paste0(colnames(type_values), "=", s),
                                    perl = TRUE)
                paste0(subbed, collapse = "")
            })
        }
    })

    if (!is.null(join_by)) {
        oper <- vapply(expanded_types, function(l) {
            paste0(l, collapse = paste0(" ", join_by, " "))
        }, character(1))

        oper_return <- gsub_many(skeleton,
                                 paste0("%expand%", seq_along(orig)),
                                 oper)
    } else {
        oper <- do.call(cbind, expanded_types)
        oper_return <- apply(oper, 1, function(i) {
          gsub_many(skeleton,
                    paste0("%expand%", seq_along(orig)),
                    i)
        })
    }
    if (verbose) {
        cat("Generated expanded expression:\n")
        cat(unlist(oper_return), sep = "\n")
    }
    return(oper_return)
}



#' Get parameter names
#'
#' Parameter names taken from \code{P} matrix or model if no
#' \code{P}  matrix provided
#'
#' @inheritParams CausalQueries_internal_inherit_params
#' @param include_paramset Logical. Whether to include the param set
#'   prefix as part of the name.
#' @return A character vector with the names of the parameters in the model
#' @noRd
#' @keywords internal

get_parameter_names <- function(model, include_paramset = TRUE) {

    if (include_paramset) {
      return(model$parameters_df$param_names)
    }

    if (!include_paramset) {
      return(model$parameters_df$nodal_type)
    }
}


#' Check whether argument is a model
#'
#' @inheritParams CausalQueries_internal_inherit_params
#' @return An error message if argument is not a model.
#' @keywords internal
#' @noRd

is_a_model <- function(model){
  minimum_components <- c("nodes",
                          "statement",
                          "nodal_types",
                          "parameters_df" )
  missing_components <- !minimum_components %in% names(model)

  if(!is(model,"causal_model")) {
    stop("Argument 'model' must be of class 'causal_model'")
  }

  if(any(missing_components)) {
    stop(paste(
      "Model doesn't contain",
      paste(minimum_components[missing_components], collapse = ", ")
    ))
  }
}

#' Warn about improper query specification and apply fixes
#'
#' @param query a string specifying a query
#' @return fixed query as string
#' @noRd
#' @keywords internal

check_query <- function(query) {
  # nonlinear indicators  to exclude
  non_linear_operators <- c("\\^", "/", "exp\\(", "log\\(")
  non_linear_warn <- any(
    vapply(non_linear_operators, function(operator) {grepl(operator, query)}, logical(1))
  )

  query <- gsub(" ", "", query)
  query <- unlist(strsplit(query, ""))

  q <- c()
  do_warn <- 0
  non_do_warn <- 0
  nest_level <- 0

  for (i in seq_along(query)) {
    write <- TRUE

    if (query[i] == "[") {
      nest_level <- nest_level + 1
    }

    if (query[i] == "]") {
      nest_level <- nest_level - 1
    }

    if (i > 1) {
      if ((nest_level != 0) && (query[i - 1] == "=") &&
          (query[i] == "=")) {
        write <- FALSE
        do_warn <- do_warn + 1
      }

      if ((nest_level == 0) &&
          (query[i - 1] == "=") &&
          !(query[i - 2] %in% c(">", "<", "!", "=")) && (query[i] != "=")) {
        q <- c(q, "=")
        non_do_warn <- non_do_warn + 1
      }
    }

    if (write) {
      q <- c(q, query[i])
    }
  }

  query <- paste(q, collapse = "")

  if (do_warn != 0) {
    warning(
      paste(
        "do operations should be specified with `=` not `==`.",
        "The query has been changed accordingly:",
        query,
        sep = " "
      )
    )
  }

  if (non_do_warn != 0) {
    warning(
      paste(
        "statements to the effect that the realization of a node should equal",
        "some value should be specified with `==` not `=`. The query has been",
        "changed accordingly:",
        query,
        sep = " "
      )
    )
  }

  if (non_linear_warn) {
    warning(
        "Non-linear transformations (such as /, ^, exp() or log()) are not supported in querying."
    )
  }

  return(query)
}

#' helper to compute mean and sd of a distribution data.frame
#' @param x An object for summarizing
#' @noRd
#' @keywords internal
summarise_distribution <- function(x) {
  summary <- c(mean(x, na.rm = TRUE), sd(x, na.rm = TRUE))
  names(summary) <- c("mean", "sd")
  return(summary)
}

#' helper to find rounding thresholds for print methods
#' @param x An object for rounding
#' @noRd
#' @keywords internal

find_rounding_threshold <- function(x) {
  x <- max(abs(x)) - min(abs(x))
  pow <- 1
  x_pow <- x * 10^pow

  while(x_pow < 1) {
    pow <- pow + 1
    x_pow <- x * 10^pow
  }

  return(pow + 1)
}

#' helper to extract arguments for a specific function
#' @param fun a function to be checked
#' @param dots a named list with possible arguments
#' @noRd
#' @keywords internal

get_args_for <- function(fun, dots) {
  formal_args <- names(formals(fun))
  # Exclude arguments with no name
  return(dots[names(dots) %in% formal_args])
}


has_posterior <- function(model) {
  !is.null(model$posterior_distribution)
}

