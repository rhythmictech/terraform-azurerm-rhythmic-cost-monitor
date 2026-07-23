# Subscription cost management exports, the analog of the AWS Cost and Usage
# Report collection (cur.tf). Gated on enable_cost_exports. Two daily exports
# (ActualCost and AmortizedCost) write MonthToDate CSVs into a dedicated,
# hardened storage account so Datadog Cloud Cost Management can ingest them.
#
# Known gap (README): the azurerm 4.x export schema exposes no file-partitioning
# or overwrite toggle. Datadog CCM prefers partitioned exports; whether it
# accepts these as-is is a live-validation item, and may need an azapi or portal
# follow-up.

locals {
  cost_exports_enabled = var.enable_cost_exports ? 1 : 0

  # Datadog CCM role grants only make sense when exports exist, the CCM opt-in is
  # set, and we actually know which principal to grant.
  datadog_cost_enabled = var.enable_cost_exports && var.enable_datadog_cost_management && var.datadog_principal_id != null

  export_storage_account_name = substr(
    replace(lower("${var.name_prefix}cost${local.subscription_guid}"), "/[^a-z0-9]/", ""),
    0,
    24,
  )

  # The two export flavors Datadog CCM consumes.
  cost_exports = {
    actual = {
      type        = "ActualCost"
      root_folder = "actual"
    }
    amortized = {
      type        = "AmortizedCost"
      root_folder = "amortized"
    }
  }

  # Datadog integration principal grants: read on the export blobs, plus Cost
  # Management Reader on the subscription (the IAM-policy-on-DatadogIntegrationRole
  # analog). Keys are static so for_each is known at plan time even though the
  # storage account scope is computed.
  datadog_cost_roles = local.datadog_cost_enabled ? {
    blob_reader = {
      role_definition_name = "Storage Blob Data Reader"
      scope                = azurerm_storage_account.exports[0].id
    }
    cost_reader = {
      role_definition_name = "Cost Management Reader"
      scope                = local.subscription_id
    }
  } : {}
}

# Export destination storage. Hardened (TLS 1.2 floor, HTTPS only, no public blob
# access, blob versioning) with a lifecycle rule that deletes noncurrent
# versions after 32 days, matching the AWS bucket's noncurrent-version
# expiration.
#
# Public network access stays enabled: the Cost Management export service writes
# from outside the resource's VNet and is not covered by the storage account's
# trusted-service bypass, so a Deny default action would block exports. Access is
# still gated on Azure AD data-plane roles, and only the Datadog principal is
# granted read.
#
# Trivy ignores are deliberate tradeoffs for a cost-export store:
#   avd-azu-0012: the export writer is not a trusted service, so public network
#                 access is required for exports to land.
#   avd-azu-0057: request-level diagnostics belong on Azure Monitor diagnostic
#                 settings, not legacy Storage Analytics logging.
#   avd-azu-0058: LRS is a deliberate cost choice; the exports are reproduced
#                 daily and do not need geo-redundancy.
# (prevent_destroy is intentionally not set; see the .tflint.hcl note.)
#trivy:ignore:avd-azu-0012
#trivy:ignore:avd-azu-0057
#trivy:ignore:avd-azu-0058
resource "azurerm_storage_account" "exports" {
  count = local.cost_exports_enabled

  name                              = local.export_storage_account_name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = true
  infrastructure_encryption_enabled = true
  tags                              = local.tags

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_management_policy" "exports" {
  count = local.cost_exports_enabled

  storage_account_id = azurerm_storage_account.exports[0].id

  rule {
    name    = "expire-noncurrent-versions"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      version {
        delete_after_days_since_creation = 32
      }
    }
  }
}

resource "azurerm_storage_container" "exports" {
  count = local.cost_exports_enabled

  name                  = "cost-exports"
  storage_account_id    = azurerm_storage_account.exports[0].id
  container_access_type = "private"
}

resource "azurerm_subscription_cost_management_export" "exports" {
  for_each = local.cost_exports_enabled == 1 ? local.cost_exports : {}

  name                         = "${var.name_prefix}cost-export-${each.key}"
  subscription_id              = local.subscription_id
  recurrence_type              = "Daily"
  recurrence_period_start_date = var.billing_period_start_date
  recurrence_period_end_date   = var.budget_end_date

  export_data_options {
    type       = each.value.type
    time_frame = "MonthToDate"
  }

  export_data_storage_location {
    container_id     = azurerm_storage_container.exports[0].id
    root_folder_path = each.value.root_folder
  }
}

resource "azurerm_role_assignment" "datadog_cost" {
  for_each = local.datadog_cost_roles

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = var.datadog_principal_id
}
