% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/set_prior_distribution.R
\name{set_prior_distribution}
\alias{set_prior_distribution}
\title{Add prior distribution draws}
\usage{
set_prior_distribution(model, n_draws = 4000)
}
\arguments{
\item{model}{A \code{causal_model}. A model object generated by
\code{\link{make_model}}.}

\item{n_draws}{A scalar. Number of draws.}
}
\value{
An object of class \code{causal_model}. It essentially returns a
  list containing the elements comprising a model
  (e.g. 'statement', 'nodal_types' and 'DAG') with the `prior_distribution`
  attached to it.
}
\description{
Add `n_param x n_draws` database of possible lambda draws to the model.
}
\examples{
make_model('X -> Y') \%>\%
  set_prior_distribution(n_draws = 5) \%>\%
  get_prior_distribution()

}
\seealso{
Other prior_distribution: 
\code{\link{get_prior_distribution}()},
\code{\link{make_prior_distribution}()}
}
\concept{prior_distribution}
