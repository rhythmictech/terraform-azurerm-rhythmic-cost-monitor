terraform {
  # >= 1.9 is REQUIRED: input-variable `validation {}` blocks reference the
  # variable's own value (and other variables), and `terraform test` uses
  # `mock_provider` (>= 1.7) for the plan-only suite.
  required_version = ">= 1.9"

  required_providers {
    # azurerm for every resource this module creates. The Action Group budgets
    # and metric alerts fire into is an input id, and the expiring-reservations
    # Function calls the Datadog REST API at runtime, so no datadog provider is
    # needed here.
    #
    # v4 is the current major (subscription_id is mandatory in the provider
    # block on v4 -> the example sets it). Do not leave >= 3.x, which silently
    # resolves to v4 with breaking changes unguarded.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    # archive zips the Function source dir into the artifact the Linux Function
    # App deploys (mirrors the AWS module's use of archive_file for the Lambda).
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2"
    }
  }
}
