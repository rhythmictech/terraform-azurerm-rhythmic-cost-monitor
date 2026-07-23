# Standardized Rhythmic tag set (team/service + terraform metadata), merged with
# user var.tags. The tags module is pure string manipulation with no provider
# requirement of its own, so it keeps this module azurerm-only. enforce_case and
# names drive the module's Name output, which locals.tf drops via tags_no_name.
module "tags" {
  source  = "rhythmictech/tags/terraform"
  version = "~> 1.1"

  enforce_case = "UPPER"
  names        = ["Rhythmic-CostMonitoring"]

  tags = merge({
    team    = "Rhythmic"
    service = "azure_managed_services"
  }, var.tags)
}

# The subscription the module is invoked against. Its id scopes the budgets, the
# anomaly alert, and the Cost Management exports, and its guid seeds the globally
# unique storage account names. The caller never passes a subscription id
# (mirrors the AWS module reading data.aws_caller_identity).
data "azurerm_subscription" "current" {}
