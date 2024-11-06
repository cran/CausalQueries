## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)


## ----setup, message = FALSE, warning = FALSE----------------------------------

library(CausalQueries)
library(knitr)
library(ggplot2)
library(rstan)
library(bayesplot)
rstan_options(refresh = 0)


## ----eval = FALSE-------------------------------------------------------------
#  data <- data.frame(X = rep(c(0:1), 10), Y = rep(c(0:1), 10))
#  
#  model <- make_model("X -> Y") |>
#    update_model(data)

## ----include = FALSE----------------------------------------------------------
data <- data.frame(X = rep(c(0:1), 10), Y = rep(c(0:1), 10))

model <- make_model("X -> Y") |> 
  update_model(data, refresh = 0)

## -----------------------------------------------------------------------------
inspect(model, "posterior_distribution")

## -----------------------------------------------------------------------------
model |> 
  query_model(
    query = "Y[X=1] > Y[X=0]",
    using = c("priors", "posteriors")) |>
  kable(digits = 2)

## -----------------------------------------------------------------------------
inspect(model, "stan_summary")

## ----eval = FALSE-------------------------------------------------------------
#  model <- make_model("X -> Y") |>
#    update_model(data, keep_fit = TRUE)

## ----include = FALSE----------------------------------------------------------
model <- make_model("X -> Y") |> 
  update_model(data, refresh = 0, keep_fit = TRUE)

## -----------------------------------------------------------------------------
model |> inspect("stanfit")

## -----------------------------------------------------------------------------
model |> inspect("stanfit") |>
  bayesplot::mcmc_pairs(pars = c("lambdas[3]", "lambdas[4]", "lambdas[5]", "lambdas[6]"))


## -----------------------------------------------------------------------------
np <- model |> inspect("stanfit") |> bayesplot::nuts_params()
head(np) |> kable()

model |> 
  inspect("stanfit") |>
  bayesplot::mcmc_trace(pars = "lambdas[5]", np = np) 

