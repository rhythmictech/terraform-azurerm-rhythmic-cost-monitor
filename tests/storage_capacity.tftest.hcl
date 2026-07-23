mock_provider "azurerm" {
  source = "./tests/setup"
}

# A two-entry monitored-account map renders two metric alerts, each with a
# dynamic-threshold criterion on UsedCapacity firing into the cost Action Group.
run "capacity_alerts" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]
    datadog_api_key             = "example-key"

    storage_capacity_monitored_account_ids = {
      workload1 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/workload1"
      workload2 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/workload2"
    }
    storage_capacity_alert_sensitivity = "High"
  }

  assert {
    condition     = length(azurerm_monitor_metric_alert.storage_capacity) == 2
    error_message = "a two-entry monitored-account map should render two metric alerts"
  }

  assert {
    condition     = contains(azurerm_monitor_metric_alert.storage_capacity["workload1"].scopes, "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/data/providers/Microsoft.Storage/storageAccounts/workload1")
    error_message = "the alert should be scoped to the monitored storage account"
  }

  assert {
    condition     = one(azurerm_monitor_metric_alert.storage_capacity["workload1"].dynamic_criteria).metric_name == "UsedCapacity"
    error_message = "the criterion should watch the UsedCapacity metric"
  }

  assert {
    condition     = one(azurerm_monitor_metric_alert.storage_capacity["workload1"].dynamic_criteria).metric_namespace == "Microsoft.Storage/storageAccounts"
    error_message = "the criterion should use the storage accounts metric namespace"
  }

  assert {
    condition     = one(azurerm_monitor_metric_alert.storage_capacity["workload1"].dynamic_criteria).operator == "GreaterOrLessThan"
    error_message = "the dynamic criterion should catch both growth and loss"
  }

  assert {
    condition     = one(azurerm_monitor_metric_alert.storage_capacity["workload1"].dynamic_criteria).alert_sensitivity == "High"
    error_message = "the alert sensitivity should pass through"
  }

  assert {
    condition     = one(azurerm_monitor_metric_alert.storage_capacity["workload1"].action).action_group_id == var.action_group_id
    error_message = "the alert should fire into the cost Action Group"
  }
}

# No monitored accounts by default: no metric alerts.
run "no_capacity_alerts_by_default" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]
    datadog_api_key             = "example-key"
  }

  assert {
    condition     = length(azurerm_monitor_metric_alert.storage_capacity) == 0
    error_message = "no metric alerts should exist when no accounts are monitored"
  }
}
