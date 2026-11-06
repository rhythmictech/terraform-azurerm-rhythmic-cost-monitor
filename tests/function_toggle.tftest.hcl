mock_provider "azurerm" {
  source = "./tests/setup"
}

# Default (enabled): the Function, its Linux consumption service plan, and its
# backing storage account are all present, with a user-assigned identity,
# Python stack, and the timer/Datadog environment app settings wired.
run "monitor_enabled_by_default" {
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
    condition     = length(azurerm_linux_function_app.expiring_reservations) == 1
    error_message = "the Function app should be created when the monitor is enabled"
  }

  assert {
    condition     = length(azurerm_service_plan.expiring_reservations) == 1
    error_message = "the service plan should be created when the monitor is enabled"
  }

  assert {
    condition     = length(azurerm_storage_account.function) == 1
    error_message = "the Function backing storage account should be created when the monitor is enabled"
  }

  assert {
    condition     = azurerm_service_plan.expiring_reservations[0].os_type == "Linux"
    error_message = "the service plan should be Linux"
  }

  assert {
    condition     = azurerm_service_plan.expiring_reservations[0].sku_name == "Y1"
    error_message = "the service plan should be the Y1 consumption SKU"
  }

  assert {
    condition     = one(azurerm_linux_function_app.expiring_reservations[0].identity).type == "UserAssigned"
    error_message = "the Function app should run as a user-assigned managed identity"
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.cost_monitor) == 1
    error_message = "the module should create the cost-monitor identity when none is supplied"
  }

  assert {
    condition     = azurerm_user_assigned_identity.cost_monitor[0].name == "id-rhythmic-cost-monitor"
    error_message = "the created identity should be named id-<name_prefix>cost-monitor"
  }

  assert {
    condition     = length(one(azurerm_linux_function_app.expiring_reservations[0].identity).identity_ids) == 1
    error_message = "the Function app should reference exactly one user-assigned identity"
  }

  assert {
    condition     = one(one(azurerm_linux_function_app.expiring_reservations[0].site_config).application_stack).python_version == "3.11"
    error_message = "the Function app should run the Python 3.11 stack"
  }

  assert {
    condition     = azurerm_linux_function_app.expiring_reservations[0].app_settings["DD_API_KEY"] == "example-key"
    error_message = "the Datadog API key should be wired as an app setting"
  }

  assert {
    condition     = azurerm_linux_function_app.expiring_reservations[0].app_settings["WARNING_EXP"] == "30"
    error_message = "the warning window should default to 30 days as an app setting"
  }

  assert {
    condition     = azurerm_linux_function_app.expiring_reservations[0].app_settings["ALERT_EXP"] == "7"
    error_message = "the alert window should default to 7 days as an app setting"
  }

  assert {
    condition     = azurerm_linux_function_app.expiring_reservations[0].app_settings["DD_SITE"] == "datadoghq.com"
    error_message = "the Datadog site should default to datadoghq.com as an app setting"
  }
}

# Disabling the monitor removes the Function, plan, and backing storage entirely.
# The Function App name is a global DNS label, so a caller can override it when
# the name_prefix default is already taken; the service plan name stays as is.
run "function_name_override" {
  command = plan

  variables {
    action_group_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name                 = "rhythmic-monitoring"
    location                            = "eastus"
    billing_period_start_date           = "2026-08-01T00:00:00Z"
    anomaly_notification_emails         = ["anomaly@example.com"]
    datadog_api_key                     = "example-key"
    expiring_reservations_function_name = "client-expiring-reservations"
  }

  assert {
    condition     = azurerm_linux_function_app.expiring_reservations[0].name == "client-expiring-reservations"
    error_message = "the Function App should take expiring_reservations_function_name when it is set"
  }

  assert {
    condition     = azurerm_service_plan.expiring_reservations[0].name == "rhythmic-expiring-reservations"
    error_message = "the service plan name should stay name_prefix + expiring-reservations"
  }
}

# A caller-supplied identity is used as is: nothing is created and the Function
# is told which identity to use through AZURE_CLIENT_ID.
run "supplied_identity" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]
    datadog_api_key             = "example-key"
    user_assigned_identity = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-example"
      client_id = "11111111-1111-1111-1111-111111111111"
    }
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.cost_monitor) == 0
    error_message = "no identity should be created when one is supplied"
  }

  assert {
    condition     = contains(one(azurerm_linux_function_app.expiring_reservations[0].identity).identity_ids, "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-example")
    error_message = "the Function app should reference the supplied identity"
  }

  assert {
    condition     = azurerm_linux_function_app.expiring_reservations[0].app_settings["AZURE_CLIENT_ID"] == "11111111-1111-1111-1111-111111111111"
    error_message = "AZURE_CLIENT_ID should carry the supplied identity's client id"
  }
}

run "monitor_disabled" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]

    enable_expiring_reservations_monitor = false
    datadog_api_key                      = null
  }

  assert {
    condition     = length(azurerm_linux_function_app.expiring_reservations) == 0
    error_message = "the Function app should not be created when the monitor is disabled"
  }

  assert {
    condition     = length(azurerm_service_plan.expiring_reservations) == 0
    error_message = "the service plan should not be created when the monitor is disabled"
  }

  assert {
    condition     = length(azurerm_storage_account.function) == 0
    error_message = "the Function backing storage account should not be created when the monitor is disabled"
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.cost_monitor) == 0
    error_message = "no identity should be created when the monitor is disabled"
  }
}

# Enabling the monitor without a Datadog API key must trip the variable
# validation (the Function cannot post events without it).
run "enabled_without_api_key_fails" {
  command = plan

  variables {
    action_group_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
    resource_group_name         = "rhythmic-monitoring"
    location                    = "eastus"
    billing_period_start_date   = "2026-08-01T00:00:00Z"
    anomaly_notification_emails = ["anomaly@example.com"]

    enable_expiring_reservations_monitor = true
    datadog_api_key                      = null
  }

  expect_failures = [
    var.datadog_api_key,
  ]
}
