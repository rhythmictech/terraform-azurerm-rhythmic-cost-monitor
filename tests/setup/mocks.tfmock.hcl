# Shared mock defaults for `terraform test`. Referenced from every *.tftest.hcl
# via `mock_provider "azurerm" { source = "./tests/setup" }`, so all plan-only
# tests run with no live Azure tenant. Only the resource and data source types
# this module touches are mocked. The archive provider is NOT mocked: it really
# zips ./function during plan, exercising the Function packaging.

# The subscription the module derives its budget/anomaly/export scope from. A
# fixed all-zero guid keeps the scope (and the derived storage names)
# deterministic across runs.
mock_data "azurerm_subscription" {
  defaults = {
    id              = "/subscriptions/00000000-0000-0000-0000-000000000000"
    subscription_id = "00000000-0000-0000-0000-000000000000"
    display_name    = "mock-subscription"
    tenant_id       = "11111111-1111-1111-1111-111111111111"
    state           = "Enabled"
  }
}

mock_resource "azurerm_consumption_budget_subscription" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Consumption/budgets/mock"
  }
}

mock_resource "azurerm_cost_anomaly_alert" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.CostManagement/scheduledActions/mock"
  }
}

mock_resource "azurerm_storage_account" {
  defaults = {
    id                        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Storage/storageAccounts/mock"
    primary_access_key        = "mock-primary-access-key"
    primary_connection_string = "DefaultEndpointsProtocol=https;AccountName=mock;AccountKey=mock;EndpointSuffix=core.windows.net"
    primary_blob_endpoint     = "https://mock.blob.core.windows.net/"
  }
}

mock_resource "azurerm_storage_container" {
  defaults = {
    id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Storage/storageAccounts/mock/blobServices/default/containers/cost-exports"
    resource_manager_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Storage/storageAccounts/mock/blobServices/default/containers/cost-exports"
  }
}

mock_resource "azurerm_storage_management_policy" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Storage/storageAccounts/mock/managementPolicies/default"
  }
}

mock_resource "azurerm_service_plan" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Web/serverFarms/mock"
  }
}

mock_resource "azurerm_linux_function_app" {
  defaults = {
    id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Web/sites/mock"
    default_hostname = "mock.azurewebsites.net"
  }
}

mock_resource "azurerm_monitor_metric_alert" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Insights/metricAlerts/mock"
  }
}

mock_resource "azurerm_subscription_cost_management_export" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.CostManagement/exports/mock"
  }
}

mock_resource "azurerm_role_assignment" {
  defaults = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-000000000001"
  }
}
