# terraform-azurerm-rhythmic-cost-monitor

Cost governance monitoring for a Rhythmic-managed Azure subscription. The module
emits cost events into a single shared Action Group (and, for the expiring
reservations Function, into Datadog directly) and lets the downstream monitoring
backend classify and fan them out. It produces events and budgets; it does not
own the routing rules.

Called once per subscription (with an aliased provider), it can create:

- **Subscription budgets**: one `azurerm_consumption_budget_subscription` per
  entry in `service_budgets`, either a whole-subscription budget (the special
  key `total`) or a per-service budget filtered on the Cost Management
  `ServiceName` dimension. Each budget notifies the shared cost Action Group.
  Empty by default, because budget amounts are client-specific cost decisions.
- **Cost anomaly alert**: one `azurerm_cost_anomaly_alert` scoped to the
  subscription. Azure anomaly detection tunes itself, so there is no impact
  threshold or frequency knob to set.
- **Expiring reservations and savings plans monitor (opt-in, on by default)**: a
  timer-triggered Linux Python Function that reports soon-to-expire reservations
  and savings plans to the Datadog Events API. This is the port of the AWS
  `monitor_sps_and_ris` Lambda. Toggle with `enable_expiring_reservations_monitor`.
- **Cost Management exports (opt-in)**: a hardened storage account plus daily
  `ActualCost` and `AmortizedCost` `azurerm_subscription_cost_management_export`
  resources for Datadog Cloud Cost Management, with optional role assignments for
  the Datadog integration principal. Toggle with `enable_cost_exports`.
- **Storage capacity anomaly alerts (opt-in)**: one `azurerm_monitor_metric_alert`
  per monitored storage account, using a dynamic threshold on `UsedCapacity` to
  catch both anomalous growth and anomalous loss, firing into the cost Action
  Group.

The subscription scope is derived from the invoking credential
(`data.azurerm_subscription`), so the caller never passes a subscription id. The
module requires the `azurerm` and `archive` providers (archive zips the Function
source); it does not use a `datadog` provider, because the Function calls the
Datadog REST API at runtime.

## Usage

```hcl
module "cost_monitor" {
  source  = "rhythmictech/rhythmic-cost-monitor/azurerm"
  version = "~> 0.1"

  # Typically the rhythmic-core module's outputs.
  action_group_id     = module.core.cost_action_group_id
  resource_group_name = module.core.resource_group_name
  location            = module.core.resource_group_location

  billing_period_start_date = "2026-08-01T00:00:00Z"

  service_budgets = {
    total      = { amount = 10000 }
    appService = { amount = 500, threshold = 80 }
  }

  # A Datadog events-by-email intake address, so anomalies become Datadog events.
  anomaly_notification_emails = ["cost-anomaly-intake@example.com"]

  # Required while the expiring-reservations monitor is enabled.
  datadog_api_key = var.datadog_api_key

  tags = {
    managed_by = "terraform"
  }
}
```

Until this module is published to the Terraform Registry, pin it by git ref:

```hcl
module "cost_monitor" {
  source = "git::https://github.com/rhythmictech/terraform-azurerm-rhythmic-cost-monitor.git?ref=v0.1.0"
  # ...
}
```

See [`examples/basic`](examples/basic) for a runnable configuration.

## Budgets and the service shorthand map

`service_budgets` is keyed by a shorthand from `azure_service_shorthand_map`, or
by the special key `total` for a whole-subscription budget with no service
filter. Each shorthand maps to a Cost Management `ServiceName` dimension value
(for example `appService` to `Azure App Service`).

The default `azure_service_shorthand_map` ships best-known values, but the
authoritative `ServiceName` strings only come from the subscription's own cost
data. Before relying on a service budget, confirm the mapped value against the
subscription's actual Cost Management `ServiceName` dimension values (Cost
Management, Cost analysis, group by Service name), and override the map where
they differ.

### Interface differences from the AWS budgets module

- **No `limit_unit`.** Budget amounts are in the subscription's billing
  currency; there is no per-budget currency field.
- **No `notification_type`.** Azure folds the actual-versus-forecast choice into
  `threshold_type` (`Actual` or `Forecasted`).
- **No DAILY grain.** Azure supports `Monthly`, `Quarterly`, or `Annually` only.
- **Evaluation cadence.** Azure budgets evaluate roughly every 4 to 24 hours,
  not in real time, so a breach notification can lag actual spend.
- **Immutable start date.** `billing_period_start_date` must be the first of a
  month and cannot change after a budget is created; changing it forces the
  budgets and exports to be replaced.

## Anomaly alert routing

Azure cost anomaly alerts deliver by email only: the resource exposes
`email_addresses`, with no Action Group or webhook target. To keep Datadog the
classification hub (and the PagerDuty and Slack fan-out downstream), pass a
Datadog events-by-email intake address in `anomaly_notification_emails` so each
anomaly email becomes a Datadog event. Creating the intake address and
confirming the resulting event shape is an onboarding and validation step.

Compared with the AWS anomaly subscription, there is no absolute or percentage
impact threshold and no frequency setting; Azure's detector self-tunes.

## Expiring reservations Function

The Function runs with a system-assigned managed identity. Reservation and
savings-plan visibility additionally requires the **Reservations Reader** role
(`Microsoft.Capacity`) at **tenant scope**, granted to the Function's identity
out of band by a billing or tenant admin. The Terraform identity cannot assign a
tenant-scope role, so this grant is an onboarding step, not a module-owned
resource (the same pattern as the directory-role bootstrap elsewhere in the
suite).

The warning and alert windows are passed to the Function as the `WARNING_EXP`
and `ALERT_EXP` app settings, because timer triggers take no input payload
(unlike the AWS EventBridge rule's input JSON).

## Cost Management exports

The export storage account keeps public network access enabled: the Cost
Management export service writes from outside the resource's VNet and is not
covered by the storage account's trusted-service bypass, so a Deny default
network action would block exports. Access is still gated on Azure AD data-plane
roles, and only the Datadog integration principal is granted read.

**Known gap:** the azurerm export schema exposes no file-partitioning or
overwrite toggle. Datadog Cloud Cost Management prefers partitioned exports;
whether it accepts these exports as-is is a live-validation item and may need an
`azapi` or portal follow-up.

## Storage capacity alerts

Dynamic thresholds need lookback history to arm, so a brand-new storage account
only starts alerting once enough `UsedCapacity` data has accumulated. The metric
is emitted hourly; the alert evaluates every hour over a six-hour window.

## Descoped follow-ups

The following are intentionally not implemented in this version:

- **Reservation and savings-plan utilization budgets.** Azure has no utilization
  budget type; `azurerm_cost_management_scheduled_action` is only a scheduled
  email of a saved view, not an alert. Azure-native reservation-utilization
  alerts are portal or API only today.
- **Export forwarding and aggregation.** There is no Azure analog of the AWS CUR
  aggregator, so exports are collected per subscription without a central
  forwarding target.
- **Application Insights for the Function.** The Function logs to the platform
  only; wiring App Insights is a possible follow-up.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.2 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.8.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.81.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_tags"></a> [tags](#module\_tags) | rhythmictech/tags/terraform | ~> 1.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_consumption_budget_subscription.service](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/consumption_budget_subscription) | resource |
| [azurerm_cost_anomaly_alert.cost](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cost_anomaly_alert) | resource |
| [azurerm_linux_function_app.expiring_reservations](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app) | resource |
| [azurerm_monitor_metric_alert.storage_capacity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_metric_alert) | resource |
| [azurerm_role_assignment.datadog_cost](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_service_plan.expiring_reservations](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |
| [azurerm_storage_account.exports](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_account.function](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.exports](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_management_policy.exports](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_management_policy) | resource |
| [azurerm_subscription_cost_management_export.exports](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_cost_management_export) | resource |
| [archive_file.function](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_action_group_id"></a> [action\_group\_id](#input\_action\_group\_id) | Resource ID of the shared cost-alerts Action Group budget and storage-capacity alerts fire into (typically the rhythmic-core module's cost\_action\_group\_id output). | `string` | n/a | yes |
| <a name="input_anomaly_alert_email_subject"></a> [anomaly\_alert\_email\_subject](#input\_anomaly\_alert\_email\_subject) | Subject line of the cost anomaly alert email. | `string` | `"Azure cost anomaly detected"` | no |
| <a name="input_anomaly_notification_emails"></a> [anomaly\_notification\_emails](#input\_anomaly\_notification\_emails) | Email addresses the subscription cost anomaly alert notifies. Typically a single Datadog events-by-email intake address so anomalies become Datadog events (Azure cost anomaly alerts support email only, no Action Group or webhook). | `list(string)` | n/a | yes |
| <a name="input_azure_service_shorthand_map"></a> [azure\_service\_shorthand\_map](#input\_azure\_service\_shorthand\_map) | Shorthand to Azure Cost Management ServiceName dimension value. Check the values against the subscription's actual Cost Management ServiceName dimension before relying on them; authoritative strings only come from the tenant's cost data. | `map(string)` | <pre>{<br/>  "appService": "Azure App Service",<br/>  "bandwidth": "Bandwidth",<br/>  "cognitiveServices": "Cognitive Services",<br/>  "functions": "Functions",<br/>  "keyVault": "Key Vault",<br/>  "monitor": "Azure Monitor",<br/>  "serviceBus": "Service Bus",<br/>  "sql": "SQL Database",<br/>  "storage": "Storage",<br/>  "vm": "Virtual Machines"<br/>}</pre> | no |
| <a name="input_billing_period_start_date"></a> [billing\_period\_start\_date](#input\_billing\_period\_start\_date) | First day of the month budgets and cost exports begin, RFC3339 (e.g. 2026-08-01T00:00:00Z). Must be the first of a month. Immutable after create; changing it forces budget/export replacement. | `string` | n/a | yes |
| <a name="input_budget_end_date"></a> [budget\_end\_date](#input\_budget\_end\_date) | End of the budget and export recurrence period, RFC3339. Azure requires an explicit end date; the default is a far-future date so budgets effectively run indefinitely. | `string` | `"2036-01-01T00:00:00Z"` | no |
| <a name="input_datadog_api_key"></a> [datadog\_api\_key](#input\_datadog\_api\_key) | Datadog API key the expiring-reservations Function uses to post events. Required (non-null) when enable\_expiring\_reservations\_monitor is true. | `string` | `null` | no |
| <a name="input_datadog_principal_id"></a> [datadog\_principal\_id](#input\_datadog\_principal\_id) | Object (principal) ID of the Datadog integration service principal. Required for the Datadog Cost Management role assignments; when null those assignments are skipped. | `string` | `null` | no |
| <a name="input_datadog_site"></a> [datadog\_site](#input\_datadog\_site) | Datadog site the Function posts events to (e.g. datadoghq.com for US1, datadoghq.eu for EU1). | `string` | `"datadoghq.com"` | no |
| <a name="input_enable_cost_exports"></a> [enable\_cost\_exports](#input\_enable\_cost\_exports) | Create the export storage account and the daily ActualCost and AmortizedCost subscription cost management exports (the analog of AWS Cost and Usage Report collection). | `bool` | `false` | no |
| <a name="input_enable_datadog_cost_management"></a> [enable\_datadog\_cost\_management](#input\_enable\_datadog\_cost\_management) | When exports are enabled, grant the Datadog integration principal read access to the export storage and Cost Management Reader on the subscription so Datadog Cloud Cost Management can ingest the data. | `bool` | `false` | no |
| <a name="input_enable_expiring_reservations_monitor"></a> [enable\_expiring\_reservations\_monitor](#input\_enable\_expiring\_reservations\_monitor) | Deploy the Function that reports soon-to-expire reservations and savings plans to Datadog. Toggle off to skip the Function, its service plan, and its backing storage account. | `bool` | `true` | no |
| <a name="input_expiring_reservations_alert_days"></a> [expiring\_reservations\_alert\_days](#input\_expiring\_reservations\_alert\_days) | Reservations and savings plans expiring within this many days are reported as an alert-level (error) Datadog event. | `number` | `7` | no |
| <a name="input_expiring_reservations_warning_days"></a> [expiring\_reservations\_warning\_days](#input\_expiring\_reservations\_warning\_days) | Reservations and savings plans expiring within this many days (but more than the alert window) are reported as a warning-level Datadog event. | `number` | `30` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for regional resources (Function app, storage), typically the rhythmic-core module's resource\_group\_location output. | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for all resource names created by this module. | `string` | `"rhythmic-"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the (existing) resource group the Function app, storage, and metric alerts are created in (typically the rhythmic-core module's resource\_group\_name output). | `string` | n/a | yes |
| <a name="input_service_budgets"></a> [service\_budgets](#input\_service\_budgets) | Cost budgets keyed by an azure\_service\_shorthand\_map shorthand, or the special key "total" for a whole-subscription budget (no service filter). Empty by default: budget amounts are client-specific cost decisions, and placeholder amounts only generate noise. | <pre>map(object({<br/>    amount         = number<br/>    time_grain     = optional(string, "Monthly")<br/>    threshold      = optional(number, 90)<br/>    threshold_type = optional(string, "Actual")<br/>    operator       = optional(string, "GreaterThan")<br/>  }))</pre> | `{}` | no |
| <a name="input_storage_capacity_alert_sensitivity"></a> [storage\_capacity\_alert\_sensitivity](#input\_storage\_capacity\_alert\_sensitivity) | Dynamic-threshold sensitivity for the storage capacity anomaly alerts: Low, Medium, or High. | `string` | `"Medium"` | no |
| <a name="input_storage_capacity_monitored_account_ids"></a> [storage\_capacity\_monitored\_account\_ids](#input\_storage\_capacity\_monitored\_account\_ids) | Storage account resource IDs to watch for anomalous capacity growth or loss, keyed by a short label used in the alert name. | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | User-defined tags merged onto all taggable resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_anomaly_alert_id"></a> [anomaly\_alert\_id](#output\_anomaly\_alert\_id) | Resource ID of the subscription cost anomaly alert. |
| <a name="output_budget_ids"></a> [budget\_ids](#output\_budget\_ids) | Map of service\_budgets key to the resource ID of its subscription budget. |
| <a name="output_export_storage_account_id"></a> [export\_storage\_account\_id](#output\_export\_storage\_account\_id) | Resource ID of the cost-export storage account, or null when exports are disabled. |
| <a name="output_function_app_id"></a> [function\_app\_id](#output\_function\_app\_id) | Resource ID of the expiring-reservations Function app, or null when the monitor is disabled. |
| <a name="output_storage_capacity_alert_ids"></a> [storage\_capacity\_alert\_ids](#output\_storage\_capacity\_alert\_ids) | Map of monitored-account label to the resource ID of its storage capacity metric alert. |
<!-- END_TF_DOCS -->
