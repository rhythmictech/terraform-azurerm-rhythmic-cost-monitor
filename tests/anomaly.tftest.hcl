mock_provider "azurerm" {
  source = "./tests/setup"
}

# Exactly one subscription cost anomaly alert is created, scoped to the current
# subscription, with the supplied notification emails and subject passed through.
run "anomaly_alert" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    datadog_api_key             = "example-key"
    anomaly_notification_emails = ["dd-intake@example.com", "ops@example.com"]
    anomaly_alert_email_subject = "Custom anomaly subject"
  }

  assert {
    condition     = azurerm_cost_anomaly_alert.cost.name == "rhythmic-cost-anomaly"
    error_message = "the anomaly alert name should be name_prefix + cost-anomaly"
  }

  assert {
    condition     = contains(azurerm_cost_anomaly_alert.cost.email_addresses, "dd-intake@example.com")
    error_message = "the anomaly alert should notify the supplied intake address"
  }

  assert {
    condition     = length(azurerm_cost_anomaly_alert.cost.email_addresses) == 2
    error_message = "both supplied notification emails should be passed through"
  }

  assert {
    condition     = azurerm_cost_anomaly_alert.cost.email_subject == "Custom anomaly subject"
    error_message = "the anomaly alert email subject should pass through"
  }

  assert {
    condition     = azurerm_cost_anomaly_alert.cost.subscription_id == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "the anomaly alert should be scoped to the current subscription"
  }
}
