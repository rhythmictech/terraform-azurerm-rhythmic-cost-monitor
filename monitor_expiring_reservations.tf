# Expiring reservations and savings plans monitor: the Azure port of the AWS
# monitor_sps_and_ris Lambda. A timer-triggered Linux Python Function enumerates
# the tenant's reservations and savings plans daily and posts a Datadog event
# for anything expiring inside the warning or alert window. All of it is gated on
# enable_expiring_reservations_monitor.
#
# RBAC bootstrap (README + client onboarding, NOT owned here): the Function's
# system-assigned identity additionally needs the Reservations Reader role
# (Microsoft.Capacity) at tenant scope, granted out of band by a billing or
# tenant admin. The Terraform identity cannot assign a tenant-scope role.
#
# App Insights is intentionally left unwired in this version (README follow-up);
# the Function logs to the platform only.

locals {
  expiring_reservations_enabled = var.enable_expiring_reservations_monitor ? 1 : 0

  # Storage account names must be 3-24 chars, lowercase alphanumerics only, and
  # globally unique. Seed from name_prefix + a fixed infix + the subscription
  # guid, strip non-alphanumerics, then clamp to 24 chars.
  function_storage_account_name = substr(
    replace(lower("${var.name_prefix}fn${local.subscription_guid}"), "/[^a-z0-9]/", ""),
    0,
    24,
  )
}

# Backing storage for the Function runtime. Hardened: TLS 1.2 floor, HTTPS only,
# no public blob access.
#
# A Y1 consumption Function App reaches its backing storage (content share, run
# state) over the public endpoint, and the Functions runtime is not covered by
# the storage account's trusted-service bypass, so a Deny network default action
# would break the Function. Access stays gated on account keys held only by the
# Function's own configuration.
#
# Trivy ignores are deliberate tradeoffs for an ephemeral Function runtime store:
#   avd-azu-0012: public reachability is required by the consumption runtime.
#   avd-azu-0057: request-level diagnostics belong on Azure Monitor diagnostic
#                 settings, not legacy Storage Analytics logging.
#   avd-azu-0058: LRS is a deliberate cost choice; the contents are ephemeral
#                 runtime state, not data needing geo-redundancy.
# (prevent_destroy is intentionally not set; see the .tflint.hcl note.)
#trivy:ignore:avd-azu-0012
#trivy:ignore:avd-azu-0057
#trivy:ignore:avd-azu-0058
resource "azurerm_storage_account" "function" {
  count = local.expiring_reservations_enabled

  name                              = local.function_storage_account_name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  tags                              = local.tags
}

# Linux consumption plan (Y1). Consumption keeps the daily timer job effectively
# free, matching the AWS Lambda's cost profile.
resource "azurerm_service_plan" "expiring_reservations" {
  count = local.expiring_reservations_enabled

  name                = "${var.name_prefix}expiring-reservations"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = local.tags
}

# Zip the Function source. The archive provider runs at plan time (it is not
# mocked in tests), mirroring the AWS module's archive_file for the Lambda.
data "archive_file" "function" {
  count = local.expiring_reservations_enabled

  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/function.zip"
}

resource "azurerm_linux_function_app" "expiring_reservations" {
  count = local.expiring_reservations_enabled

  name                = "${var.name_prefix}expiring-reservations"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.expiring_reservations[0].id

  storage_account_name       = azurerm_storage_account.function[0].name
  storage_account_access_key = azurerm_storage_account.function[0].primary_access_key
  https_only                 = true

  tags = local.tags

  # System-assigned identity: DefaultAzureCredential in the Function picks this
  # up; the tenant-scope Reservations Reader grant is bootstrapped out of band.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    # Timer triggers take no input payload (unlike EventBridge), so the warning
    # and alert windows are passed as environment variables the Function reads.
    WARNING_EXP = tostring(var.expiring_reservations_warning_days)
    ALERT_EXP   = tostring(var.expiring_reservations_alert_days)

    # Datadog Events API credentials the Function posts with.
    DD_API_KEY = var.datadog_api_key
    DD_SITE    = var.datadog_site

    # Zip deploy must pip-install requirements.txt remotely (Oryx build).
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    ENABLE_ORYX_BUILD              = "true"
  }

  zip_deploy_file = data.archive_file.function[0].output_path
}
