% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_type_prob.R
\name{get_type_prob_multiple}
\alias{get_type_prob_multiple}
\title{Draw matrix of type probabilities, before or after estimation}
\usage{
get_type_prob_multiple(
  model,
  using = "priors",
  parameters = NULL,
  n_draws = 4000,
  param_dist = NULL,
  P = NULL
)
}
\arguments{
\item{model}{A \code{causal_model}. A model object generated by
\code{\link{make_model}}.}

\item{using}{A character. It indicates whether to use
`priors`, `posteriors` or `parameters`.}

\item{parameters}{A vector of real numbers in [0,1]. Values of parameters to
specify (optional). By default, parameters is drawn from
\code{model$parameters_df}.}

\item{n_draws}{An integer. If no prior distribution is provided, generate
prior distribution with \code{n_draws} number of draws.}

\item{param_dist}{A \code{matrix}.  Distribution of parameters.
Optional for speed.}

\item{P}{A \code{data.frame}. Parameter matrix. Not required but may be
provided to avoid repeated computation for simulations.}
}
\value{
A \code{matrix} of type probabilities.
}
\description{
Draw matrix of type probabilities, before or after estimation
}
\examples{
model <- make_model('X -> Y')
get_type_prob_multiple(model, using = 'priors', n_draws = 3)
get_type_prob_multiple(model, using = 'parameters', n_draws = 3)
}
