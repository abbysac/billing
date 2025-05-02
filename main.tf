

locals {
  csvfld = csvdecode(file("./csvdata.csv"))
}

resource "aws_budgets_budget" "budget_notification" {
  for_each          = { for BudgetName in local.csvfld : BudgetName.BudgetName => BudgetName }
  name              = each.value.BudgetName
  budget_type       = "COST"
  limit_amount      = each.value.BudgetAmount
  limit_unit        = "USD"
#   time_period_start = each.value.StartMonth
#   time_period_end   = each.value.EndMonth
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 85
    threshold_type             = "PERCENTAGE"
    notification_type          = each.value.Alert1Trigger
    subscriber_email_addresses = [each.value.Alert1Emails]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = each.value.Alert2Trigger
    subscriber_email_addresses = [each.value.Alert2Emails]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = each.value.Alert3Trigger
    subscriber_email_addresses = [each.value.Alert3Emails]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = each.value.Alert4Trigger
    subscriber_email_addresses = [each.value.Alert4Emails]
  }

}


output "csvdata" {
  value = local.csvfld
}


resource "aws_iam_role" "github_oidc_role" {
  name = "GitHubActionsOIDCRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::224761220970:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:abbysac/billing:*"
          }
        }
      }
    ]
  })

  # Add this inline policy to grant the necessary permission
  inline_policy {
    name = "list-role-policies"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "iam:ListRolePolicies"
          Resource = "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole"
        }
      ]
    })
  }

  # Include any other existing policies or configurations here
}