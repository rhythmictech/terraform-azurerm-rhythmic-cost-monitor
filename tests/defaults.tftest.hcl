mock_provider "azurerm" {
  source = "./tests/setup"
}

# Default happy path with only the required inputs: no budgets, exactly one
# anomaly alert, the expiring-reservations Function present, no exports, no
# Datadog role assignments, and no storage capacity alerts.
run "defaults" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["dd-intake@example.com"]
    datadog_api_key             = "example-key"
  }

  # Budgets are opt-in: none by default.
  assert {
    condition     = length(azurerm_consumption_budget_subscription.service) == 0
    error_message = "no budgets should be created by default"
  }

  # Exactly one anomaly alert, with the supplied intake address.
  assert {
    condition     = contains(azurerm_cost_anomaly_alert.cost.email_addresses, "dd-intake@example.com")
    error_message = "the anomaly alert should notify the supplied intake address by default"
  }

  # The Function stack is present by default (monitor enabled).
  assert {
    condition     = length(azurerm_linux_function_app.expiring_reservations) == 1
    error_message = "the expiring-reservations Function should be created by default"
  }

  assert {
    condition     = azurerm_service_plan.expiring_reservations[0].sku_name == "Y1"
    error_message = "the default service plan should be the Y1 consumption SKU"
  }

  assert {
    condition     = azurerm_linux_function_app.expiring_reservations[0].app_settings["DD_API_KEY"] == "example-key"
    error_message = "the Datadog API key should be wired by default"
  }

  # No exports and no Datadog role assignments by default.
  assert {
    condition     = length(azurerm_subscription_cost_management_export.exports) == 0
    error_message = "no cost exports should be created by default"
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog_cost) == 0
    error_message = "no Datadog role assignments should exist by default"
  }

  # No storage capacity alerts by default.
  assert {
    condition     = length(azurerm_monitor_metric_alert.storage_capacity) == 0
    error_message = "no storage capacity alerts should exist by default"
  }
}
