

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


# 1. OIDC provider for GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["74F3A68F16524F15424927704C9506F55A9316BD"] # GitHub's current thumbprint
}


# 2. IAM Role for GitHub Actions
resource "aws_iam_role" "github_oidc_role" {
  name = "GitHubActionsOIDCRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:abbysac/billing:*"
        }
      }
    }]
  })
}

# 3. Permissions for the role
resource "aws_iam_role_policy" "github_oidc_policy" {
  name = "GitHubOIDCPolicy"
  role = aws_iam_role.github_oidc_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetObject",
          "sts:GetCallerIdentity",
          
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetOpenIDConnectProvider",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy"
        ]
        Resource = [
            "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole", 
            "arn:aws:iam::224761220970:oidc-provider/token.actions.githubusercontent.com"
        ]
      }
    ]
  })
}
