
.runThisTest <- Sys.getenv("RunAllRcppTests") == "yes"

if (.runThisTest) {

context("Testing get_event_prob")

testthat::test_that(
	desc = "Testing warnings",
	code = {
		model <- make_model("X -> Y")
		expect_error(get_event_prob(model = model, parameters = rnorm(6)),"Negative arguments for parameters not allowed")
	}
)


testthat::test_that(
	desc = "Testing hack",
	code = {
		model <- make_model("X -> Y") %>%
			set_restrictions(c("(X[]==1)", "(Y[X=.]==1)"))
		expect_true(row.names(get_event_prob(model = model))==colnames(get_ambiguities_matrix(model)))
	}
)

}
