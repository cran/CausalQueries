
.runThisTest <- Sys.getenv("RunAllRcppTests") == "yes"

if (.runThisTest) {

context("get_causal_types")

testthat::test_that(
	desc = "Test get_causal_types output.",
	code = {
		model <- make_model("X -> Y")
		model$causal_types <- NULL
		expect_equal(nrow(get_causal_types(model)), 8)
	}
)
}
