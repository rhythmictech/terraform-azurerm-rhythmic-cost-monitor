terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# azurerm v4 makes subscription_id mandatory in the provider block.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Minimal invocation: one whole-subscription budget and one service budget, the
# subscription cost anomaly alert routed to a Datadog events-by-email intake
# address, the expiring-reservations Function, and one storage account watched
# for capacity anomalies. In a real deployment action_group_id,
# resource_group_name, and location come from the rhythmic-core module's
# outputs, and datadog_api_key comes from a secret.
module "cost_monitor" {
  source = "../../"

  action_group_id     = var.action_group_id
  resource_group_name = var.resource_group_name
  location            = var.location

  billing_period_start_date = "2026-08-01T00:00:00Z"

  service_budgets = {
    total = {
      amount = 10000
    }
    appService = {
      amount    = 500
      threshold = 80
    }
  }

  anomaly_notification_emails = ["cost-anomaly-intake@example.com"]

  datadog_api_key = var.datadog_api_key

  storage_capacity_monitored_account_ids = {
    workload = "/subscriptions/${var.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Storage/storageAccounts/workloaddata"
  }

  tags = {
    managed_by = "terraform"
    module     = "terraform-azurerm-rhythmic-cost-monitor"
  }
}
