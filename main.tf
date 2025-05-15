locals {
  csvfld = csvdecode(file("./csvdata.csv"))
#   accounts = {
#     for row in local.csvfld :
#     "${row.AccountId}_${row.BudgetName}" => {
#       account_id        = row.AccountId
#       budget_name       = row.BudgetName
#       budget_amount     = row.BudgetAmount
#       alert_threshold   = row.Alert1Threshold
#       alert_trigger     = row.Alert1Trigger
#       sns_topic_arn     = row.SNSTopicArn
#       linked_accounts   = contains(keys(row), "linked_accounts") ? jsondecode(row.linked_accounts) : []
#     }
#   }
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
    threshold                  = each.value.Alert1Threshold
    threshold_type             = "PERCENTAGE"
    notification_type          = each.value.Alert1Trigger
    # subscriber_email_addresses = [each.value.Alert1Emails]
    subscriber_sns_topic_arns  = ["arn:aws:sns:us-east-1:224761220970:budget-updates-topic"]
    
   
  }
}
  # notification {
  #   comparison_operator        = "GREATER_THAN"
  #   threshold                  = 100
  #   threshold_type             = "PERCENTAGE"
  #   notification_type          = each.value.Alert2Trigger
  #   # subscriber_email_addresses = [each.value.Alert2Emails]
  #   subscriber_sns_topic_arns  = ["arn:aws:sns:us-east-1:224761220970:budget-updates-topic"]
    
  # }

#   # notification {
#   #   comparison_operator        = "GREATER_THAN"
#   #   threshold                  = 100
#   #   threshold_type             = "PERCENTAGE"
#   #   notification_type          = each.value.Alert3Trigger
#   #   # subscriber_email_addresses = [each.value.Alert3Emails]
#   #   subscriber_sns_topic_arns  = ["arn:aws:sns:us-east-1:224761220970:budget-updates-topic"]
    
#   # }

#   # notification {
#   #   comparison_operator        = "GREATER_THAN"
#   #   threshold                  = 70
#   #   threshold_type             = "PERCENTAGE"
#   #   notification_type          = each.value.Alert4Trigger
#   #   # subscriber_email_addresses = [each.value.Alert4Emails]
#   #   subscriber_sns_topic_arns  = ["arn:aws:sns:us-east-1:224761220970:budget-updates-topic"]
    
  
#   # }

# # }


# output "csvdata" {
#   value = local.csvfld
# }

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
            "iam:ListAttachedRolePolicies",
            "lambda:GetFunction",
            "lambda:ListVersionsByFunction"
           
            
        ]
        Resource = [
            "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole",      
            "arn:aws:iam::224761220970:oidc-provider/token.actions.githubusercontent.com",
            "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert"
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
            "budgets:ListTagsForResource",
            "lambda:GetPolicy",
            "logs:DescribeLogGroups",
            "logs:ListTagsForResource",
            "budgets:DescribeBudgetActionsForAccount",
            "budgets:DescribeBudgetPerformanceHistory",
            "budgets:DescribeBudgets",
            "iam:CreatePolicyVersion",
            "iam:GetRole",
            "iam:ListRolePolicies",
            "iam:ListAttachedRolePolicies",
            "iam:ListEntitiesForPolicy",
            "lambda:GetFunctionCodeSigningConfig",
            "SNS:GetSubscriptionAttributes"
            
           
        ]
        Resource = [

              "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole",      
              "arn:aws:iam::224761220970:oidc-provider/token.actions.githubusercontent.com"
          ]  #"arn:aws:budgets::data.aws_caller_identity.current.224761220970:budget/*"
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
      SENDER_EMAIL = "abbysac@gmail.com"
      RECIPIENT_EMAILS = "camleous@yahoo.com"
    }
  }
}
resource "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/budget_update_gha_alert"
}


# resource "aws_s3_bucket" "my_bucket" {
#   bucket = "my-import-bucket234"
# }

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "budget_update_gha_alert"
  principal     = "sns.amazonaws.com"
  source_arn    = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
}

resource "aws_lambda_permission" "allow_ssm" {
  statement_id  = "AllowExecutionFromSSM"
  action        = "lambda:InvokeFunction"
  function_name = "budget_update_gha_alert"
  principal     = "ssm.amazonaws.com"
}

resource "aws_sns_topic_subscription" "lambda_target" {
  topic_arn = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
  protocol  = "lambda"
  endpoint  = "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert"
}


data "aws_iam_policy_document" "lambda_invoke_permission" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::224761220970:role/AWS-SystemsManager-AutomationAdministrationRole"]
    }

    actions = [
      "lambda:InvokeFunction"
    ]

    resources = [
      "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert"
    ]
  }
}






  ##Use the aws_budgets_budget resource from the Terraform Registry to create budgets, 
  ##leveraging the for_each meta-argument for iteration. In main.tf, add:

# resource "aws_budgets_budget" "budget_notification" {
#   for_each     = local.accounts
#   name         = each.value.budget_name
#   budget_type  = "COST"
#   limit_amount = each.value.budget_amount
#   limit_unit   = "USD"
#   time_unit    = "MONTHLY"

#   dynamic "cost_filter" {
#   for_each = contains(keys(each.value), "linked_accounts") && length(each.value.linked_accounts) > 0 ? [1] : []
#   content {
#     name   = "LinkedAccount"
#     values = each.value.linked_accounts
#   }
# }


#   notification {
#     comparison_operator        = "GREATER_THAN"
#     threshold                  = each.value.alert_threshold
#     threshold_type             = "PERCENTAGE"
#     notification_type          = each.value.alert_trigger
#     subscriber_sns_topic_arns  = [each.value.sns_topic_arn]
#   }
# }


# IAM Role for SSM Automation in Management Account
resource "aws_iam_role" "ssm_automation_admin" {
  name = "AWS-SystemsManager-AutomationAdministrationRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [    
        {
          Effect    = "Allow"
          Principal = {
             Service = "ssm.amazonaws.com"
            }
          Action    = "sts:AssumeRole"
        },
         {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ssm_automation_policy" {
  name = "SSMAutomationPolicy"
  role = aws_iam_role.ssm_automation_admin.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "organizations:ListAccounts",
          "sns:Publish",
          "budgets:DescribeBudget",
          "budgets:ViewBudget"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_lambda_invoke" {
  name        = "SSMInvokeLambdaPolicy"
  description = "Allow SSM automation role to invoke central budget Lambda"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ssm_lambda_invoke" {
  role       = "AWS-SystemsManager-AutomationAdministrationRole"
  policy_arn = aws_iam_policy.ssm_lambda_invoke.arn
}




resource "aws_ssm_document" "invoke_central_lambda" {
  name          = "budget_update_gha_alert"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Assume role in target account and invoke central Lambda"

    parameters = {
      TargetAccountId = {
        type    = "String"
        default = "224761220970"
      }
      RoleName = {
        type    = "String"
        default = "AWS-SystemsManager-AutomationAdministrationRole"
      }
      LambdaFunctionName = {
        type    = "String"
        default = "budget_update_gha_alert"
      }
      AutomationAssumeRole = {
        type    = "String"
        default = "arn:aws:iam::224761220970:role/AWS-SystemsManager-AutomationAdministrationRole"
      }
      SnsTopicArn = {
        type    = "String"
        default = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
      }
      BudgetName = {
        type    = "String"
        default = "ABC Operations DEV Account Overall Budget"
      }
    }

    mainSteps = [
      {
        name   = "assumeRole"
        action = "aws:executeAwsApi"
        inputs = {
          Service         = "sts"
          Api             = "AssumeRole"
          RoleArn         = "{{ AutomationAssumeRole }}"
          RoleSessionName = "InvokeCentralLambdaSession"
        }
        outputs = [
          { Name = "AccessKeyId", Selector = "$.Credentials.AccessKeyId", Type = "String" },
          { Name = "SecretAccessKey", Selector = "$.Credentials.SecretAccessKey", Type = "String" },
          { Name = "SessionToken", Selector = "$.Credentials.SessionToken", Type = "String" }
        ]
      },
      {
        name   = "invokeLambda"
        action = "aws:executeScript"
        inputs = {
          Runtime = "python3.8"
          Handler = "handler"
          Script = <<EOF
import boto3

def handler(event, context):
    results = []
    account_id = event.get("TargetAccountId", "unknown")

    try:
        session = boto3.Session(
            aws_access_key_id=event["Credentials"]["AccessKeyId"],
            aws_secret_access_key=event["Credentials"]["SecretAccessKey"],
            aws_session_token=event["Credentials"]["SessionToken"]
        )

        budgets = session.client("budgets")
        sns = session.client("sns")

        budget_response = budgets.describe_budget(
            AccountId=account_id,
            BudgetName=event["BudgetName"]
        )

        budget_limit = float(budget_response["Budget"]["BudgetLimit"]["Amount"])
        actual_spend = float(budget_response["Budget"]["CalculatedSpend"]["ActualSpend"]["Amount"])

        if actual_spend / budget_limit >= 0.8:
            sns.publish(
                TopicArn=event["SnsTopicArn"],
                Message=(
                    f'The budget "{event["BudgetName"]}" for account {account_id} has exceeded 80% of its limit. '
                    f'Actual spend: {actual_spend} USD, Budget limit: {budget_limit} USD.'
                ),
                Subject=f'Budget Alert: "{event["BudgetName"]}" Exceeded 70% for Account {account_id}'
            )

        results.append({
            "account_id": account_id,
            "status": "checked",
            "actual_spend": actual_spend,
            "budget_limit": budget_limit
        })

    except Exception as e:
        results.append({
            "account_id": account_id,
            "error": str(e)
        })

    return {"results": results}
EOF

          InputPayload = {
            TargetAccountId = "{{ TargetAccountId }}"
            BudgetName      = "{{ BudgetName }}"
            SnsTopicArn     = "{{ SnsTopicArn }}"
            Credentials = {
              AccessKeyId     = "{{ assumeRole.AccessKeyId }}"
              SecretAccessKey = "{{ assumeRole.SecretAccessKey }}"
              SessionToken    = "{{ assumeRole.SessionToken }}"
            }
          }
        }
      }
    ]
  })
}
