#' Puts your DAG into 'dagitty' syntax (useful for using their plotting functions)
#'
#' If confounds are indicated (provided in \code{attr(model$P, 'confounds')}), then these are represented as bidirectional arcs.
#'
#' @inheritParams CausalQueries_internal_inherit_params
#'
#' @keywords internal
#'
#' @return A \code{\link[dagitty]{dagitty}} translation of \code{DAG}
#'
#' @examples
#' \dontrun{
#' model <- make_model('X -> Y')
#' CausalQueries:::translate_dagitty(model)
#' }
#'
translate_dagitty <- function(model) {

    if (length(model$nodes) == 1)
        return(paste0("dag{ ", model$statement, " }"))

    dag <- model$dag
    inner <- paste(paste0(apply(dag, 1, paste, collapse = " -> "), collapse = " ; "), collapse = "")

    if (!is.null(model$P) && !is.null(model$confounds_df) && all(!is.na(model$confounds_df))) {
        conf_df <- model$confounds_df
        inner <- paste(inner, " ; ", paste(paste(conf_df[, 1], conf_df[, 2], sep = " <-> "), collapse = " ; "))
    }

    dagitty_dag <- paste0("dag{ ", inner, " }")
    return(dagitty_dag)
}

#' Plot your dag using 'dagitty'
#'
#'@inheritParams CausalQueries_internal_inherit_params
#'
#' @keywords internal
#' @importFrom graphics plot
#' @return No return value.
#' @examples
#' \donttest{
#' model <- make_model('X -> K -> Y; X -> Y')
#' CausalQueries:::plot_dag(model)
#' model <- CausalQueries:::make_model('X -> K -> Y; X <-> Y')
#' CausalQueries:::plot_dag(model)
#' }
#'

plot_dag <- function(model) {
    if (!is.null(model$P) & is.null(model$confounds_df)) {
        message("Model has a P matrix but no confounds_df. confounds_df generated on the fly. To avoid this message try model <- set_confounds_df(model)")
        model <- set_confounds_df(model)
    }
    dagitty_dag <- translate_dagitty(model)
    plot(dagitty::graphLayout(dagitty_dag))
}

#' @export
plot.causal_model <- function(x, ...) {
    plot_dag(x)
}

