output "budget_ids" {
  description = "Map of service_budgets key to the resource ID of its subscription budget."
  value       = { for k, r in azurerm_consumption_budget_subscription.service : k => r.id }
}

output "anomaly_alert_id" {
  description = "Resource ID of the subscription cost anomaly alert."
  value       = azurerm_cost_anomaly_alert.cost.id
}

output "function_app_id" {
  description = "Resource ID of the expiring-reservations Function app, or null when the monitor is disabled."
  value       = one(azurerm_linux_function_app.expiring_reservations[*].id)
}

output "export_storage_account_id" {
  description = "Resource ID of the cost-export storage account, or null when exports are disabled."
  value       = one(azurerm_storage_account.exports[*].id)
}

output "storage_capacity_alert_ids" {
  description = "Map of monitored-account label to the resource ID of its storage capacity metric alert."
  value       = { for k, r in azurerm_monitor_metric_alert.storage_capacity : k => r.id }
}
