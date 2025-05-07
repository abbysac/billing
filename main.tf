

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
    threshold                  = 80
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
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = each.value.Alert4Trigger
    # subscriber_email_addresses = [each.value.Alert4Emails]
    subscriber_sns_topic_arns  = ["arn:aws:sns:us-east-1:224761220970:budget-updates-topic"]
  }

}


output "csvdata" {
  value = local.csvfld
}

#1. OIDC provider for GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["74f3a68f16524f15424927704c9506f55a9316bd"] # GitHub's current thumbprint
}

# Define the IAM role without inline_policy
resource "aws_iam_role" "github_oidc_role" {
  name = "GitHubActionsOIDCRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
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
}

# Define the inline policy separately
resource "aws_iam_role_policy" "github_oidc_policy" {
  name = "list-role-policies"
  role = aws_iam_role.github_oidc_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
            "iam:ListRolePolicies",
            "iam:GetOpenIDConnectProvider",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListAttachedRolePolicies"
        ]
        Resource = [
            "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole",      
            "arn:aws:iam::224761220970:oidc-provider/token.actions.githubusercontent.com"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "budgets_view_policy" {
  name        = "budgets-view-policy"
  description = "Allows viewing AWS Budgets"
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
            "budgets:ViewBudget",
            "iam:GetPolicy",
            "iam:GetPolicyVersion",
            "budgets:ListTagsForResource"
        ]
        Resource =  "*"  #"arn:aws:budgets::data.aws_caller_identity.current.224761220970:budget/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "budgets_view_attachment" {
  role       = aws_iam_role.github_oidc_role.name
  policy_arn = aws_iam_policy.budgets_view_policy.arn
}

# Get the current AWS account ID dynamically
data "aws_caller_identity" "current" {}

# account_id = data.aws_caller_identity.current.account_id


resource "aws_iam_policy" "policy" {
  name        = "budget_sns_gha_policy"
  path        = "/"
  description = "budget_sns_gha_policy"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "SNSFullAccess",
        "Effect" : "Allow",
        "Action" : "sns:*",
        "Resource" : "*"
      },
      { "Sid" : "SESFullAccess"
        "Effect" : "Allow",
        "Action" : "ses:SendEmail",
        "Resource" : "*"
      },
      {
        "Sid" : "SMSAccessViaSNS",
        "Effect" : "Allow",
        "Action" : [
          "sms-voice:DescribeVerifiedDestinationNumbers",
          "sms-voice:CreateVerifiedDestinationNumber",
          "sms-voice:SendDestinationNumberVerificationCode",
          "sms-voice:SendTextMessage",
          "sms-voice:DeleteVerifiedDestinationNumber",
          "sms-voice:VerifyDestinationNumber",
          "sms-voice:DescribeAccountAttributes",
          "sms-voice:DescribeSpendLimits",
          "sms-voice:DescribePhoneNumbers",
          "sms-voice:SetTextMessageSpendLimitOverride",
          "sms-voice:DescribeOptedOutNumbers",
          "sms-voice:DeleteOptedOutNumber"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:CalledViaLast" : [
              "sns.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_gha_attach" {
  name       = "budget_policy_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.policy.arn
}


resource "aws_iam_role" "lambda_role" {
  name = "lambda_budget_gha_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "scheduler.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function.zip"
  function_name = "budget_update_gha_alert"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.11"

  environment {
    variables = {
      foo = "bar"
    }
  }
}
resource "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/budget_update_gha_alert"
}


# resource "aws_s3_bucket" "my_bucket" {
#   bucket = "my-import-bucket234"
# }