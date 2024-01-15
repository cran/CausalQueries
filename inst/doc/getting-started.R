## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)


## ----setup, message = FALSE, warning = FALSE----------------------------------
if(!requireNamespace("fabricatr", quietly = TRUE)) {
  install.packages("fabricatr")
}

library(CausalQueries)
library(fabricatr)
library(knitr)

## -----------------------------------------------------------------------------
# examples of models
xy_model <- make_model("X -> Y")
iv_model <- make_model("Z -> X -> Y <-> X")


## -----------------------------------------------------------------------------
plot(iv_model)

## -----------------------------------------------------------------------------
xy_model$parameters_df |> kable()

## -----------------------------------------------------------------------------
iv_model <- 
  iv_model |> set_restrictions(decreasing('Z', 'X'))

## -----------------------------------------------------------------------------
iv_model <- 
  iv_model |> set_priors(distribution = "jeffreys")

## -----------------------------------------------------------------------------
data <- make_data(iv_model, n = 4) 

data |> kable()


## -----------------------------------------------------------------------------
df <- fabricatr::fabricate(N = 100, X = rbinom(N, 1, .5), Y = rbinom(N, 1, .25 + X*.5))

xy_model <- 
  xy_model |> 
  update_model(df, refresh = 0)

## -----------------------------------------------------------------------------

xy_model$posterior_distribution |> 
  head() |> kable()


## -----------------------------------------------------------------------------
xy_model |> 
  query_model("Y[X=1] > Y[X=0]", using = c("priors", "posteriors")) |>
  kable()

## -----------------------------------------------------------------------------
xy_model |> 
  query_model("Y[X=1] > Y[X=0]", using = c("priors", "posteriors"),
              given = "X==1 & Y == 1") |>
  kable()

## -----------------------------------------------------------------------------
xy_model |> 
  query_model("Y[X=1] > Y[X=0]", using = c("priors", "posteriors"),
              given = "Y[X=1] != Y[X=0]") |>
  kable()

