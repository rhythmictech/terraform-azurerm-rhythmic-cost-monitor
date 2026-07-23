mock_provider "azurerm" {
  source = "./tests/setup"
}

# A map with the special "total" key plus a service shorthand renders two
# subscription budgets: "total" has no filter block, the service budget filters
# on the mapped ServiceName, both notify the shared Action Group, and names
# follow the ${prefix}budget-<key>-<grain> shape.
run "total_and_service_budgets" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]
    datadog_api_key             = "example-key"

    service_budgets = {
      total = {
        amount = 10000
      }
      appService = {
        amount = 500
      }
    }
  }

  assert {
    condition     = length(azurerm_consumption_budget_subscription.service) == 2
    error_message = "a two-entry service_budgets map should render two subscription budgets"
  }

  # "total" carries no filter block (whole-subscription budget).
  assert {
    condition     = length(azurerm_consumption_budget_subscription.service["total"].filter) == 0
    error_message = "the total budget should have no filter block"
  }

  # A service budget filters on the mapped ServiceName dimension value.
  assert {
    condition     = length(azurerm_consumption_budget_subscription.service["appService"].filter) == 1
    error_message = "a service budget should carry exactly one filter block"
  }

  assert {
    condition     = one(azurerm_consumption_budget_subscription.service["appService"].filter[0].dimension).name == "ServiceName"
    error_message = "the service budget filter should be on the ServiceName dimension"
  }

  assert {
    condition     = one(one(azurerm_consumption_budget_subscription.service["appService"].filter[0].dimension).values) == "Azure App Service"
    error_message = "the appService budget should filter on the mapped ServiceName value"
  }

  # Notifications fire into the shared Action Group.
  assert {
    condition     = one(one(azurerm_consumption_budget_subscription.service["total"].notification).contact_groups) == var.action_group_id
    error_message = "budget notifications should target the supplied action_group_id"
  }

  # Amount and grain pass through; grain defaults to Monthly.
  assert {
    condition     = azurerm_consumption_budget_subscription.service["total"].amount == 10000
    error_message = "the total budget amount should pass through"
  }

  assert {
    condition     = azurerm_consumption_budget_subscription.service["total"].time_grain == "Monthly"
    error_message = "time_grain should default to Monthly"
  }

  # Name shape: ${prefix}budget-<key>-<lower(grain)>.
  assert {
    condition     = azurerm_consumption_budget_subscription.service["appService"].name == "rhythmic-budget-appService-monthly"
    error_message = "budget name should be name_prefix + budget- + key + - + lower(time_grain)"
  }

  # Scope + time period.
  assert {
    condition     = azurerm_consumption_budget_subscription.service["total"].subscription_id == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "budgets should be scoped to the current subscription id"
  }

  assert {
    condition     = one(azurerm_consumption_budget_subscription.service["total"].time_period).start_date == "2026-08-01T00:00:00Z"
    error_message = "budget time_period start_date should be billing_period_start_date"
  }
}
