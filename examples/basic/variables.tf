variable "subscription_id" {
  description = "Azure subscription id the cost monitoring is deployed into."
  type        = string
}

variable "action_group_id" {
  description = "Resource ID of the cost-alerts Action Group budgets and capacity alerts fire into."
  type        = string
  default     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rhythmic-monitoring/providers/microsoft.insights/actionGroups/rhythmic-costalerts"
}

variable "resource_group_name" {
  description = "Name of the existing resource group the Function app, storage, and alerts are created in."
  type        = string
  default     = "rhythmic-monitoring"
}

variable "location" {
  description = "Azure region for the regional resources."
  type        = string
  default     = "eastus"
}

variable "datadog_api_key" {
  description = "Datadog API key the expiring-reservations Function posts events with."
  type        = string
  sensitive   = true
  default     = "example"
}
