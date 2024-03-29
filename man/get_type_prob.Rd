% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_type_prob.R
\name{get_type_prob}
\alias{get_type_prob}
\title{Get type probabilities}
\usage{
get_type_prob(model, P = NULL, parameters = NULL)
}
\arguments{
\item{model}{A \code{causal_model}. A model object generated by
\code{\link{make_model}}.}

\item{P}{A \code{data.frame}. Parameter matrix. Not required but may be
provided to avoid repeated computation for simulations.}

\item{parameters}{A vector of real numbers in [0,1]. Values of parameters to
specify (optional). By default, parameters is drawn from
\code{model$parameters_df}.}
}
\value{
A vector with probabilities of vector of causal types
}
\description{
Gets probability of vector of causal types given a single
realization of parameters, possibly drawn from model priors.
}
\details{
By default, parameters is drawn from `using` argument
(either from priors, posteriors, or from model$parameters)
}
\examples{
get_type_prob(model = make_model('X->Y'))
get_type_prob(model = make_model('X->Y'), parameters = 1:6)

}
