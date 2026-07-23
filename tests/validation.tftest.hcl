mock_provider "azurerm" {
  source = "./tests/setup"
}

# billing_period_start_date must be the first of a month in RFC3339 form.
run "bad_billing_start_date_rejected" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-15T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]
    datadog_api_key             = "example-key"
  }

  expect_failures = [
    var.billing_period_start_date,
  ]
}

# An unknown service_budgets key (not "total" and not in the shorthand map) is
# rejected.
run "unknown_service_budget_key_rejected" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]
    datadog_api_key             = "example-key"

    service_budgets = {
      notaservice = {
        amount = 100
      }
    }
  }

  expect_failures = [
    var.service_budgets,
  ]
}

# An unsupported time_grain (Azure has no DAILY grain) is rejected.
run "bad_time_grain_rejected" {
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
        amount     = 100
        time_grain = "Daily"
      }
    }
  }

  expect_failures = [
    var.service_budgets,
  ]
}

# storage_capacity_alert_sensitivity is constrained to Low/Medium/High.
run "bad_sensitivity_rejected" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]
    datadog_api_key             = "example-key"

    storage_capacity_alert_sensitivity = "Extreme"
  }

  expect_failures = [
    var.storage_capacity_alert_sensitivity,
  ]
}
