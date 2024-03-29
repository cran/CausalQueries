## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup, warning = FALSE, message = FALSE----------------------------------
if(!requireNamespace("fabricatr", quietly = TRUE)) {
  install.packages("fabricatr")
}

library(CausalQueries)
library(fabricatr)
library(knitr)

## -----------------------------------------------------------------------------
model <- make_model("X -> M -> Y <-> X")

## -----------------------------------------------------------------------------
model <- set_priors(model, distribution = "jeffreys")

## -----------------------------------------------------------------------------
plot(model)

## ----message = FALSE, warning = FALSE-----------------------------------------
# Lets imagine highly correlated data; here an effect of .9 at each step
data <- fabricate(N = 5000, 
                  X = rep(0:1, N/2), 
                  M = rbinom(N, 1, .05 + .9*X), 
                  Y = rbinom(N, 1, .05 + .9*M))

# Updating
model <- model |> update_model(data, refresh = 0)

## -----------------------------------------------------------------------------
query_model(
    model = model, 
    using = c("priors", "posteriors"),
    query = "Y[X=1] - Y[X=0]",
    ) |>
  kable(digits = 2)

## ----message = FALSE, warning = FALSE-----------------------------------------

model |>
  update_model(data |> dplyr::select(X, Y), refresh = 0) |>
  query_model(
    using = c("priors", "posteriors"),
    query = "Y[X=1] - Y[X=0]") |>
  kable(digits = 2)

