locals {
  # Applied to every taggable resource (storage accounts, service plan, Function
  # app, metric alerts). module.tags.tags_no_name yields the standardized
  # Rhythmic tag set merged with user var.tags, excluding the Name key (mirrors
  # the sibling core and account-monitor modules). Budgets, anomaly alerts, cost
  # exports, and role assignments are not taggable in azurerm and omit this.
  tags = module.tags.tags_no_name

  # Subscription scope. Budgets and the cost management export require the full
  # "/subscriptions/<guid>" resource id; the anomaly alert accepts the same.
  subscription_id = data.azurerm_subscription.current.id

  # Bare subscription guid, used only to seed globally unique storage account
  # names (which must be 3-24 chars, lowercase alphanumerics only).
  subscription_guid = data.azurerm_subscription.current.subscription_id
}
