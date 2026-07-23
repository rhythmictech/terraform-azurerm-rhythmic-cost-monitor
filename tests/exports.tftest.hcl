mock_provider "azurerm" {
  source = "./tests/setup"
}

# Enabling cost exports creates one export storage account, one container, and
# exactly two exports: ActualCost and AmortizedCost, both daily and MonthToDate.
run "exports_enabled" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]
    datadog_api_key             = "example-key"

    enable_cost_exports = true
  }

  assert {
    condition     = length(azurerm_storage_account.exports) == 1
    error_message = "enabling cost exports should create one export storage account"
  }

  assert {
    condition     = length(azurerm_storage_container.exports) == 1
    error_message = "enabling cost exports should create one export container"
  }

  assert {
    condition     = length(azurerm_subscription_cost_management_export.exports) == 2
    error_message = "enabling cost exports should create exactly two exports (ActualCost + AmortizedCost)"
  }

  assert {
    condition     = azurerm_subscription_cost_management_export.exports["actual"].export_data_options[0].type == "ActualCost"
    error_message = "the actual export should be of type ActualCost"
  }

  assert {
    condition     = azurerm_subscription_cost_management_export.exports["amortized"].export_data_options[0].type == "AmortizedCost"
    error_message = "the amortized export should be of type AmortizedCost"
  }

  assert {
    condition     = azurerm_subscription_cost_management_export.exports["actual"].recurrence_type == "Daily"
    error_message = "exports should recur daily"
  }

  assert {
    condition     = azurerm_subscription_cost_management_export.exports["actual"].export_data_options[0].time_frame == "MonthToDate"
    error_message = "exports should use the MonthToDate time frame"
  }

  assert {
    condition     = azurerm_subscription_cost_management_export.exports["amortized"].export_data_storage_location[0].root_folder_path == "amortized"
    error_message = "the amortized export should write to the amortized root folder"
  }

  # No Datadog role assignments without the CCM opt-in.
  assert {
    condition     = length(azurerm_role_assignment.datadog_cost) == 0
    error_message = "no Datadog role assignments should exist without enable_datadog_cost_management"
  }
}

# Exports disabled by default: no storage, container, exports, or role
# assignments.
run "exports_disabled_by_default" {
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
    condition     = length(azurerm_storage_account.exports) == 0
    error_message = "no export storage account should exist by default"
  }

  assert {
    condition     = length(azurerm_subscription_cost_management_export.exports) == 0
    error_message = "no exports should exist by default"
  }
}

# Opting into Datadog Cost Management with a principal id adds two role
# assignments: Storage Blob Data Reader on the export storage and Cost
# Management Reader on the subscription.
run "datadog_cost_management_roles" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]
    datadog_api_key             = "example-key"

    enable_cost_exports            = true
    enable_datadog_cost_management = true
    datadog_principal_id           = "22222222-2222-2222-2222-222222222222"
  }

  assert {
    condition     = length(azurerm_role_assignment.datadog_cost) == 2
    error_message = "enabling Datadog Cost Management with a principal should create two role assignments"
  }

  assert {
    condition     = azurerm_role_assignment.datadog_cost["blob_reader"].role_definition_name == "Storage Blob Data Reader"
    error_message = "the storage role assignment should grant Storage Blob Data Reader"
  }

  assert {
    condition     = azurerm_role_assignment.datadog_cost["cost_reader"].role_definition_name == "Cost Management Reader"
    error_message = "the subscription role assignment should grant Cost Management Reader"
  }

  assert {
    condition     = azurerm_role_assignment.datadog_cost["blob_reader"].principal_id == "22222222-2222-2222-2222-222222222222"
    error_message = "the role assignments should target the Datadog principal id"
  }

  assert {
    condition     = azurerm_role_assignment.datadog_cost["cost_reader"].scope == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "the Cost Management Reader assignment should be scoped to the subscription"
  }
}
