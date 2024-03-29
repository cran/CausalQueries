% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_causal_types.R
\name{get_causal_types}
\alias{get_causal_types}
\title{Get causal types}
\usage{
get_causal_types(model)
}
\arguments{
\item{model}{A \code{causal_model}. A model object generated by
\code{\link{make_model}}.}
}
\value{
A \code{data.frame} indicating causal types of a \code{model}
}
\description{
Return data frame with types produced from all combinations of possible
data produced by a DAG.
}
\examples{
get_causal_types(make_model('X -> Y'))

}
