# Storage capacity growth/loss anomaly alerts. One metric alert per monitored
# storage account, watching the UsedCapacity metric with a dynamic (self-tuning)
# threshold. GreaterOrLessThan catches both anomalous growth (runaway cost) and
# anomalous loss (possible data deletion), firing into the shared cost Action
# Group. Keeping this azurerm-native avoids adding a Datadog provider dependency.
#
# UsedCapacity is emitted hourly, so the alert evaluates every hour over a
# six-hour window.
#
# README note: dynamic thresholds need lookback history to arm, so a brand-new
# storage account only starts alerting once enough capacity data has accumulated.
resource "azurerm_monitor_metric_alert" "storage_capacity" {
  for_each = var.storage_capacity_monitored_account_ids

  name                = "${var.name_prefix}storage-capacity-${each.key}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Anomalous storage capacity growth or loss on ${each.key}."
  frequency           = "PT1H"
  window_size         = "PT6H"
  severity            = 2
  tags                = local.tags

  dynamic_criteria {
    metric_namespace  = "Microsoft.Storage/storageAccounts"
    metric_name       = "UsedCapacity"
    aggregation       = "Average"
    operator          = "GreaterOrLessThan"
    alert_sensitivity = var.storage_capacity_alert_sensitivity
  }

  action {
    action_group_id = var.action_group_id
  }
}
