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
library(dplyr)
library(knitr)

## -----------------------------------------------------------------------------
# examples of models
xy_model <- make_model("X -> Y")
iv_model <- make_model("Z -> X -> Y <-> X")


## -----------------------------------------------------------------------------
plot(xy_model)

## -----------------------------------------------------------------------------
summary(xy_model)

## -----------------------------------------------------------------------------
xy_model |> inspect("parameters_df") 

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
df <- 
  data.frame(X = rbinom(100, 1, .5)) |>
  mutate(Y = rbinom(100, 1, .25 + X*.5))

xy_model <- 
  xy_model |> 
  update_model(df, refresh = 0)

## -----------------------------------------------------------------------------

xy_model |> grab("posterior_distribution") |> 
  head() |> kable()


## -----------------------------------------------------------------------------
xy_model |> 
  query_model("Y[X=1] > Y[X=0]", using = c("priors", "posteriors")) 

## -----------------------------------------------------------------------------
xy_model |> 
  query_model("Y[X=1] > Y[X=0]", using = c("priors", "posteriors"),
              given = "X==1 & Y == 1") 

## -----------------------------------------------------------------------------
xy_model |> 
  query_model("Y[X=1] > Y[X=0]", using = c("priors", "posteriors"),
              given = "Y[X=1] != Y[X=0]") 

## ----fig.height = 4, fig.width = 8--------------------------------------------
batch_queries <- xy_model |> 
  query_model(queries = c("Y[X=1] - Y[X=0]", "Y[X=1] > Y[X=0]"), 
              using = c("priors", "posteriors"), 
              given = c(TRUE, "Y[X=1] != Y[X=0]"),
              expand_grid = TRUE) 

batch_queries |> kable(digits = 2, caption = "tabular output")
batch_queries |> plot() 

