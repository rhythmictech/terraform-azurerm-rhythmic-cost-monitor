# Subscription cost budgets, one per service_budgets entry. The special key
# "total" is a whole-subscription budget (no ServiceName filter); every other
# key filters on the ServiceName dimension value looked up from
# azure_service_shorthand_map. Each budget's notification targets the shared
# cost Action Group (contact_groups), the Azure analog of an SNS subscriber.
#
# Interface differences from the AWS aws_budgets_budget module, documented in
# the README:
#   - No limit_unit: the budget amount is in the subscription's billing currency.
#   - No notification_type: Azure folds actual-vs-forecast into threshold_type.
#   - No DAILY grain: Azure supports Monthly, Quarterly, or Annually only.
#   - Budgets evaluate roughly every 4 to 24 hours, not in real time.
#   - time_period.start_date must be the first of a month and is immutable after
#     create; changing billing_period_start_date forces budget replacement.
resource "azurerm_consumption_budget_subscription" "service" {
  for_each = var.service_budgets

  name            = "${var.name_prefix}budget-${each.key}-${lower(each.value.time_grain)}"
  subscription_id = local.subscription_id
  amount          = each.value.amount
  time_grain      = each.value.time_grain

  time_period {
    start_date = var.billing_period_start_date
    end_date   = var.budget_end_date
  }

  # No filter for the whole-subscription "total" budget; otherwise filter on the
  # mapped ServiceName dimension value.
  dynamic "filter" {
    for_each = each.key == "total" ? [] : [each.key]

    content {
      dimension {
        name   = "ServiceName"
        values = [var.azure_service_shorthand_map[each.key]]
      }
    }
  }

  notification {
    enabled        = true
    operator       = each.value.operator
    threshold      = each.value.threshold
    threshold_type = each.value.threshold_type
    contact_groups = [var.action_group_id]
  }
}
