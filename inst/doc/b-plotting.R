## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  echo = TRUE,
  comment = "#>"
)


## ----setup, message = FALSE, warning = FALSE, echo = FALSE--------------------
library(dplyr)
library(CausalQueries)
library(knitr)
library(ggplot2)


## -----------------------------------------------------------------------------
model <- make_model("X -> Y")

model |> plot_model()

## -----------------------------------------------------------------------------
model |> 
  plot_model()  + 
  annotate("text", x = c(1, -1) , y = c(1.5, 1.5), label = c("Some text", "Some more text")) + 
  coord_flip()

## -----------------------------------------------------------------------------
model <- make_model("A -> B -> C <- A") 


# Check node ordering
inspect(model, "nodes")

# Provide labels
model |>
   plot_model(
     labels = c("This is A", "Here is B", "And C"),
     nodecol = "white", textcol = "black")

## -----------------------------------------------------------------------------
model |> 
  plot(x_coord = 0:2,  y_coord = c(0, 2, 1))

## -----------------------------------------------------------------------------
model |> 
  plot(x_coord = 0:2,  y_coord = c(0, 2, 1), 
       nodecol = c("blue", "orange", "red"),
       textcol = c("white", "red", "blue"))

## -----------------------------------------------------------------------------
make_model('X -> K -> Y <- X; X <-> Y; K <-> Y') |>   plot()

## -----------------------------------------------------------------------------
make_model("I -> V -> G <- N; C -> I <- A -> G; G -> Z",
           add_causal_types = FALSE) |> 
  plot() 

## -----------------------------------------------------------------------------
make_model("D <- A -> B -> C -> D -> E; B -> E",
           add_causal_types = FALSE) |> 
  plot() 

## -----------------------------------------------------------------------------
make_model("D <- A -> B -> C -> D -> E; B -> E",
           add_causal_types = FALSE) |>  
  plot(x_coord = c(0, -.1, 0, .1, 0), y_coord = 5:1) 


