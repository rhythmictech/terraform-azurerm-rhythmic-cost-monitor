# basic

Minimal invocation of `terraform-azurerm-rhythmic-cost-monitor`: one
whole-subscription budget and one service budget, the subscription cost anomaly
alert routed to a Datadog events-by-email intake address, the expiring
reservations Function, and one storage account watched for capacity anomalies.

In a real deployment `action_group_id`, `resource_group_name`, and `location`
come from the `terraform-azurerm-rhythmic-core` module's outputs, and
`datadog_api_key` comes from a secret.

```bash
terraform init
terraform plan -var 'subscription_id=00000000-0000-0000-0000-000000000000'
```
