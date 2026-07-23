# One subscription-scoped cost anomaly alert. Azure's anomaly detection tunes
# itself, so unlike the AWS aws_ce_anomaly_subscription there is no absolute or
# percentage impact threshold and no frequency knob to set (documented in the
# README as interface losses).
#
# Azure cost anomaly alerts deliver by email only: the schema exposes
# email_addresses (no Action Group, no webhook). The caller therefore passes a
# Datadog events-by-email intake address so anomalies still become Datadog
# events and the PagerDuty and Slack fan-out stays downstream, consistent with
# every other detection in the suite.
resource "azurerm_cost_anomaly_alert" "cost" {
  name            = "${var.name_prefix}cost-anomaly"
  display_name    = "Rhythmic subscription cost anomaly"
  subscription_id = local.subscription_id
  email_subject   = var.anomaly_alert_email_subject
  email_addresses = var.anomaly_notification_emails
}
