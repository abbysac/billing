#Use the aws_budgets_budget resource from the Terraform Registry to create budgets, 
#leveraging the for_each meta-argument for iteration. In main.tf, add:
resource "aws_budgets_budget" "budget_notification" {
  for_each     = local.accounts
  name         = each.value.budget_name
  budget_type  = "COST"
  limit_amount = each.value.budget_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"


  dynamic "cost_filter" {
    for_each = contains(keys(each.value), "linked_accounts") && length(each.value.linked_accounts) > 0 ? [1] : []
    content {
      name   = " LinkedAccount"
      values = each.value.linked_accounts
    }
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = each.value.alert_threshold
    threshold_type            = "PERCENTAGE"
    notification_type         = each.value.alert_trigger
    subscriber_sns_topic_arns = [each.value.sns_topic_arn]
    # subscriber_email_addresses = compact([each.value.email])
  }
}
