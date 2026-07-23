variable "action_group_id" {
  description = "Resource ID of the shared cost-alerts Action Group budget and storage-capacity alerts fire into (typically the rhythmic-core module's cost_action_group_id output)."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the (existing) resource group the Function app, storage, and metric alerts are created in (typically the rhythmic-core module's resource_group_name output)."
  type        = string
}

variable "location" {
  description = "Azure region for regional resources (Function app, storage), typically the rhythmic-core module's resource_group_location output."
  type        = string
}

variable "name_prefix" {
  description = "Prefix for all resource names created by this module."
  type        = string
  default     = "rhythmic-"
}

variable "billing_period_start_date" {
  description = "First day of the month budgets and cost exports begin, RFC3339 (e.g. 2026-08-01T00:00:00Z). Must be the first of a month. Immutable after create; changing it forces budget/export replacement."
  type        = string

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-01T00:00:00Z$", var.billing_period_start_date))
    error_message = "billing_period_start_date must be the first of a month in RFC3339 form, e.g. 2026-08-01T00:00:00Z."
  }
}

variable "budget_end_date" {
  description = "End of the budget and export recurrence period, RFC3339. Azure requires an explicit end date; the default is a far-future date so budgets effectively run indefinitely."
  type        = string
  default     = "2036-01-01T00:00:00Z"
}

variable "service_budgets" {
  description = "Cost budgets keyed by an azure_service_shorthand_map shorthand, or the special key \"total\" for a whole-subscription budget (no service filter). Empty by default: budget amounts are client-specific cost decisions, and placeholder amounts only generate noise."
  type = map(object({
    amount         = number
    time_grain     = optional(string, "Monthly")
    threshold      = optional(number, 90)
    threshold_type = optional(string, "Actual")
    operator       = optional(string, "GreaterThan")
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.service_budgets : k == "total" || contains(keys(var.azure_service_shorthand_map), k)])
    error_message = "Every service_budgets key must be \"total\" or a key of azure_service_shorthand_map."
  }

  validation {
    condition     = alltrue([for k, v in var.service_budgets : contains(["Monthly", "Quarterly", "Annually"], v.time_grain)])
    error_message = "service_budgets time_grain must be one of Monthly, Quarterly, or Annually (Azure has no DAILY budget grain)."
  }
}

variable "azure_service_shorthand_map" {
  description = "Shorthand to Azure Cost Management ServiceName dimension value. Check the values against the subscription's actual Cost Management ServiceName dimension before relying on them; authoritative strings only come from the tenant's cost data."
  type        = map(string)
  default = {
    appService        = "Azure App Service"
    sql               = "SQL Database"
    storage           = "Storage"
    functions         = "Functions"
    serviceBus        = "Service Bus"
    cognitiveServices = "Cognitive Services"
    vm                = "Virtual Machines"
    monitor           = "Azure Monitor"
    keyVault          = "Key Vault"
    bandwidth         = "Bandwidth"
  }
}

variable "anomaly_notification_emails" {
  description = "Email addresses the subscription cost anomaly alert notifies. Typically a single Datadog events-by-email intake address so anomalies become Datadog events (Azure cost anomaly alerts support email only, no Action Group or webhook)."
  type        = list(string)
}

variable "anomaly_alert_email_subject" {
  description = "Subject line of the cost anomaly alert email."
  type        = string
  default     = "Azure cost anomaly detected"
}

variable "enable_expiring_reservations_monitor" {
  description = "Deploy the Function that reports soon-to-expire reservations and savings plans to Datadog. Toggle off to skip the Function, its service plan, and its backing storage account."
  type        = bool
  default     = true
}

variable "datadog_api_key" {
  description = "Datadog API key the expiring-reservations Function uses to post events. Required (non-null) when enable_expiring_reservations_monitor is true."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = !var.enable_expiring_reservations_monitor || var.datadog_api_key != null
    error_message = "datadog_api_key must be set when enable_expiring_reservations_monitor is true."
  }
}

variable "datadog_site" {
  description = "Datadog site the Function posts events to (e.g. datadoghq.com for US1, datadoghq.eu for EU1)."
  type        = string
  default     = "datadoghq.com"
}

variable "expiring_reservations_warning_days" {
  description = "Reservations and savings plans expiring within this many days (but more than the alert window) are reported as a warning-level Datadog event."
  type        = number
  default     = 30
}

variable "expiring_reservations_alert_days" {
  description = "Reservations and savings plans expiring within this many days are reported as an alert-level (error) Datadog event."
  type        = number
  default     = 7
}

variable "enable_cost_exports" {
  description = "Create the export storage account and the daily ActualCost and AmortizedCost subscription cost management exports (the analog of AWS Cost and Usage Report collection)."
  type        = bool
  default     = false
}

variable "enable_datadog_cost_management" {
  description = "When exports are enabled, grant the Datadog integration principal read access to the export storage and Cost Management Reader on the subscription so Datadog Cloud Cost Management can ingest the data."
  type        = bool
  default     = false
}

variable "datadog_principal_id" {
  description = "Object (principal) ID of the Datadog integration service principal. Required for the Datadog Cost Management role assignments; when null those assignments are skipped."
  type        = string
  default     = null
}

variable "storage_capacity_monitored_account_ids" {
  description = "Storage account resource IDs to watch for anomalous capacity growth or loss, keyed by a short label used in the alert name."
  type        = map(string)
  default     = {}
}

variable "storage_capacity_alert_sensitivity" {
  description = "Dynamic-threshold sensitivity for the storage capacity anomaly alerts: Low, Medium, or High."
  type        = string
  default     = "Medium"

  validation {
    condition     = contains(["Low", "Medium", "High"], var.storage_capacity_alert_sensitivity)
    error_message = "storage_capacity_alert_sensitivity must be one of Low, Medium, or High."
  }
}

variable "tags" {
  description = "User-defined tags merged onto all taggable resources."
  type        = map(string)
  default     = {}
}
