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
        Effect = "Allow"
        Action = [
          "iam:ListRolePolicies",
          "iam:GetOpenIDConnectProvider",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "lambda:GetFunction",
          "lambda:ListVersionsByFunction",
          "iam:GetPolicy",
          "iam:PutRolePolicy",
          "lambda:RemovePermission",
          "lambda:AddPermission"



        ]
        Resource = [
          "*"
          # "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole",
          # "arn:aws:iam::224761220970:oidc-provider/token.actions.githubusercontent.com",
          # "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert",
          # "arn:aws:iam::224761220970:policy/budgets-view-policy"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "iam:ListPolicyVersions",
          "iam:DeletePolicyVersion",
          "iam:CreatePolicyVersion",
          "iam:CreatePolicyVersion"
        ],
        "Resource" : "arn:aws:iam::224761220970:policy/budgets-view-policy"
      },

      {
        "Effect" : "Allow",
        "Action" : [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListEntitiesForPolicy",
          "lambda:GetFunctionCodeSigningConfig",
          "logs:DescribeLogGroups",
          "logs:ListTagsForResource",
          "lambda:GetPolicy",
          "budgets:ViewBudget",
          "ssm:DescribeDocument",
          "SNS:GetSubscriptionAttributes",
          "budgets:ListTagsForResource",
          "ssm:GetDocument",
          "ssm:DescribeDocumentPermission",
          "organizations:ListOrganizationalUnitsForParent",
          "Organizations:ListRoots",
          "lambda:UpdateFunctionCode",
          "ssm:UpdateDocument",
          "iam:PutRolePolicy",
          "budgets:ModifyBudget",
          "ssm:UpdateDocumentDefaultVersion",
          "ssm:CreateDocument",
          "lambda:UpdateFunctionConfiguration",
          "ssm:GetParameter",
          "SNS:Subscribe"




        ],
        "Resource" : [
          "*"
          # "arn:aws:iam::224761220970:policy/budget_sns_gha_policy",
          # "arn:aws:iam::224761220970:role/lambda_budget_gha_role",
          # "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert",
          # "arn:aws:logs:us-east-1:224761220970:log-group:/aws/lambda/budget_update_gha_alert",
          # "arn:aws:budgets::224761220970:budget/*",
          # "arn:aws:iam::224761220970:role/AWS-SystemsManager-AutomationAdministrationRole",
          # "arn:aws:ssm:us-east-1:224761220970:document/budget_update_gha_alert",
          # "arn:aws:logs:us-east-1:224761220970:log-group::log-stream:*",
          # "arn:aws:sns:us-east-1:224761220970:budget-updates-topic",
          # "arn:aws:organizations::224761220970:root/o-wdq8jdx6ev/r-rs6a",
          # "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "organizations:DescribeOrganization",
          "organizations:ListAccounts",
          "organizations:ListAccountsForParent",
          "sts:AssumeRole",
          "Organizations:ListRoots",
          "organizations:ListOrganizationalUnitsForParent",
          "Organizations:ListAWSServiceAccessForOrganization",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:GetRole",
          "ssm:CreateDocument",
          "lambda:UpdateFunctionConfiguration",
          "ssm:StartAutomationExecution",
          "iam:DeletePolicyVersion"





        ],
        "Resource" : "*"
      }


    ]
  })
}

resource "aws_iam_policy" "budgets_view_policy" {
  name        = "budgets-view-policy"
  description = "Allows viewing AWS Budgets"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
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
          "SNS:GetSubscriptionAttributes",
          "budgets:ViewBudget",
          "iam:ListPolicyVersions",
          "iam:DeletePolicyVersion"





        ]
        Resource = [
          "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole",
          "arn:aws:iam::224761220970:oidc-provider/token.actions.githubusercontent.com",
          "arn:aws:budgets::224761220970:budget/*"

        ]

        #"arn:aws:budgets::data.aws_caller_identity.current.224761220970:budget/*"
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
      { "Sid" : "SESFullAccess",
        "Effect" : "Allow",
        "Action" : [
          "ses:SendEmail",
          "ses:SendRawEmail"

        ]
        "Resource" : "*"
      },
      { "Sid" : "EC2FullAccess",
        "Effect" : "Allow",
        "Action" : "ec2:DescribeInstances",
        "Resource" : "*"
      },
      { "Sid" : "S3FullAccess",
        "Effect" : "Allow",
        "Action" : [
          "s3:*",
          "s3:ListBucket",
          "s3:ListObject"
        ]
        "Resource" : "arn:aws:s3:::extended-sqs-s3/"
        "Condition" : {
          "StringLike" : {
            "s3:prefix" : "email_map.csv"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : ["s3:GetObject"],
        "Resource" : "arn:aws:s3:::extended-sqs-s3/*"
      },
      {
        "Sid" : "AllowSSMAutomationExecution",
        "Effect" : "Allow",
        "Action" : [
          "budgets:DescribeBudget",
          "budgets:ViewBudget",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"

        ]

        "Resource" : [
          "arn:aws:ssm:us-east-1:224761220970:parameter/budgets/default/*",
          "arn:aws:ssm:us-east-1:224761220970:automation-definition/budget_update_gha_alert",
          "arn:aws:lambda:us-east-1:224761220970:function:ssm-lambda-tag",
          "arn:aws:ssm:us-east-1:224761220970:parameter/ssm-param-tags/*",
          "arn:aws:ssm:us-east-1:224761220970:parameter/tags/"
        ]
      },
      {
        "Sid" : "BudgetAccess",
        "Effect" : "Allow",
        "Action" : [
          # "budgets:ViewBudget",
          "organizations:ListAccounts",
          "organizations:DescribeOrganization",
          "ses:SendEmail",
          "Organizations:ListRoots",
          "iam:PutRolePolicy",
          "ssm:StartAutomationExecution",
          "budgets:ViewBudget",
          "sts:GetCallerIdentity"


        ],
        "Resource" : [
          "*"

        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      },
      {
        "Sid" : "AllowStartSSMAutomation",
        "Effect" : "Allow",
        "Action" : [
          "ssm:StartAutomationExecution"
        ],
        "Resource" : "arn:aws:ssm:us-east-1:224761220970:automation-definition/budget_update_gha_alert:*"
      },
      {
        "Sid" : "AllowPassAutomationRole",
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : "arn:aws:iam::224761220970:role/AWS-SystemsManager-AutomationAdministrationRole"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameter"

        ],
        "Resource" : [
          "arn:aws:lambda:us-east-1:224761220970:function:ssm-budget-trigger",
          "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert",
          "arn:aws:ssm:us-east-1:224761220970:parameter/budget/*"
        ]
      },
      { "Sid" : "OidcAccess",
        "Effect" : "Allow",
        "Action" : [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListEntitiesForPolicy",
          "ses:SendEmail",
          "budgets:ViewBudget"

        ],
        "Resource" : [
          "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole",
          "arn:aws:budgets::224761220970:budget/ABC Operations DEV Account Overall Budget",
          "arn:aws:budgets::224761220970:budget/ABC Operations PROD Account Overall Budget",
          "arn:aws:budgets::224761220970:budget/ABC Operations QA Account Overall Budget",
          "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert",
          "arn:aws:iam::224761220970:oidc-provider/token.actions.githubusercontent.com"


        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "organizations:ListAccounts",
          "ses:SendEmail"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "organizations:ListAccounts",
          "organizations:DescribeOrganization"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "sns:Publish",
          "ssm:StartAutomationExecution"
        ],
        "Resource" : [
          # "arn:aws:ssm:us-east-1:224761220970:automation-definition/budget_update_gha_alert:*",
          "*"
        ]
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
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::224761220970:root"
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

  runtime = "python3.12"
  timeout = 180

  environment {
    variables = {
      FORCE_ALERT = true
    }
  }


}
resource "aws_cloudwatch_log_group" "lambda" {
  name = "/aws/lambda/budget_update_gha_alert"
}

resource "aws_lambda_function" "ssm_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function_ssm.zip"
  function_name = "ssm_budget_trigger_alert"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"


  source_code_hash = data.archive_file.ssm.output_base64sha256

  runtime = "python3.12"
  timeout = 180
  environment {
    variables = {
      # Add any environment variables your Lambda function needs here
      # For example:
      # "ENV_VAR_NAME" = "value"
      DEFAULT_THRESHOLD = "80"
      SNS_TOPIC_ARN     = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
      SSM_DOCUMENT_NAME = "budget_update_gha_alert"
      FORCE_ALERT       = true
    }
  }

}


resource "aws_cloudwatch_log_group" "ssm" {
  name = "/aws/lambda/ssm_budget_trigger_alert"
}




resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name #"budget_update_gha_alert"
  principal     = "sns.amazonaws.com"
  source_arn    = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
  # source_arn = "arn:aws:sns:us-east-1:224761220970:test-topic"
}

resource "aws_lambda_permission" "allow_ssm" {
  statement_id  = "AllowExecutionFromSSM"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "ssm.amazonaws.com"
  source_arn    = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
}

resource "aws_sns_topic_subscription" "lambda_target" {
  topic_arn = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
  # topic_arn  = "arn:aws:sns:us-east-1:224761220970:test-topic"
  protocol   = "lambda"
  endpoint   = "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert"
  depends_on = [aws_lambda_permission.allow_sns]
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



# IAM Role for SSM Automation in Management Account
resource "aws_iam_role" "ssm_automation_admin" {
  name = "AWS-SystemsManager-AutomationAdministrationRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS : "*"
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
          "organizations:DescribeOrganization",
          "sns:Publish",
          "organizations:ListAccountsForParent",
          "iam:PassRole"

        ]
        Resource = [

          "arn:aws:budgets::224761220970:budget/ABC Operations DEV Account Overall Budget",
          "arn:aws:budgets::224761220970:budget/ABC Operations PROD Account Overall Budget",
          "arn:aws:budgets::224761220970:budget/ABC Operations QA Account Overall Budget",
          "arn:aws:sns:us-east-1:224761220970:budget-updates-topic",
          "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole",
          "arn:aws:sns:us-east-1:224761220970:test-topic",
          "arn:aws:lambda:us-east-1:224761220970:function:ssm-budget-trigger"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "budgets:DescribeBudget",
          "budgets:ViewBudget",
          "ssm:GetParameter",
          "ssm:StartAutomationExecution"

        ],
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
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:*"
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


# data.tf

# Retrieve the AWS Organization and its accounts
data "aws_organizations_organization" "org" {}

# Filter active accounts, excluding the management account if desired
# locals {
#   active_accounts = [
#     for account in data.aws_organizations_organization.org.accounts :
#     account.id
#     if account.status == "ACTIVE" && account.id != data.aws_organizations_organization.org.master_account_id
#   ]
#   all_accounts = [
#     for account in data.aws_organizations_organization.org.accounts :
#     account.id
#     if account.status == "ACTIVE"
#   ]
# }

# Output for debugging
# output "active_linked_accounts" {
#   value = local.active_accounts
# }

# output "all_active_accounts" {
#   value = local.all_accounts
# }

# Fetch the entire organization (includes management + all member accounts)
# data "aws_organizations_organization" "org" {}

# Extract just the member (linked) account IDs
# - Skip the management account itself (optional, depending on your needs)
# - You can filter further by status, name, etc. if needed
# locals {
#   all_account_ids      = [for acc in data.aws_organizations_organization.org.accounts : acc.id]
#   linked_accounts      = [for acc in data.aws_organizations_organization.org.accounts : acc.id if acc.id != data.aws_organizations_organization.org.master_account_id]
#   linked_account_names = { for acc in data.aws_organizations_organization.org.accounts : acc.name => acc.id if acc.id != data.aws_organizations_organization.org.master_account_id }
# }

resource "aws_iam_policy" "github_actions_policy" {
  name        = "github-actions-iam-get-policy"
  description = "Allows GitHub Actions to get IAM policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["iam:GetPolicy", "iam:GetPolicyVersion"],
        Resource = "*" #"arn:aws:iam::224761220970:policy/budgets-view-policy"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_github_actions_policy" {
  role       = "GitHubActionsOIDCRole"
  policy_arn = aws_iam_policy.github_actions_policy.arn
}



# resource "aws_ssm_document" "check_budget_and_alert" {
#   name          = "budget_update_gha_alert"
#   document_type = "Automation"

#   content = jsonencode({
#     schemaVersion = "0.3"
#     description   = "Assume a role, check AWS Budgets, and publish to SNS if threshold exceeded."
#     parameters = {
#       AutomationAssumeRole = {
#         type        = "String"
#         description = "(Optional) IAM role for Automation to assume"
#         default     = "arn:aws:iam::224761220970:role/AWS-SystemsManager-AutomationAdministrationRole"
#       }
#       MemberRoleName = {
#         type    = "String"
#         default = "budget_assume_role"
#       }
#       TargetRoleArn = {
#         type        = "String"
#         description = "ARN of the IAM Role to assume in the target account"
#         default     = "arn:aws:iam::224761220970:role/AWS-SystemsManager-AutomationAdministrationRole"
#       }
#       BudgetName = {
#         type        = "StringList"
#         description = "Name of the AWS Budget to check"
#         default     = [for item in local.csvfld : item.BudgetName]
#       }
#       BudgetEmail = {
#         type        = "StringList"
#         description = "Name of the AWS Budget to check"
#         default     = [for item in local.csvfld : item.email]
#       }
#       # BudgetsToCheck = {
#       #   type        = "String"
#       #   description = "JSON string of budgets to check"
#       #   default     = "[]"
#       # }
#       ThresholdPercent = {
#         type        = "String"
#         description = "Budget threshold percentage to trigger alert"
#         default     = "80"
#       }
#       SNSTopicArn = {
#         type        = "String"
#         description = "SNS topic ARN to publish the alert to"
#         default     = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
#       }
#     }
#     mainSteps = [
#       {
#         name   = "AssumeManagementRole" #"AssumeManagementRole"
#         action = "aws:executeAwsApi"
#         inputs = {
#           Service         = "sts"
#           Api             = "AssumeRole"
#           RoleArn         = "{{ AutomationAssumeRole }}"
#           RoleSessionName = "BudgetCheck"
#         }
#         outputs = [
#           { Name = "AccessKeyId", Selector = "$.Credentials.AccessKeyId", Type = "String" },
#           { Name = "SecretAccessKey", Selector = "$.Credentials.SecretAccessKey", Type = "String" },
#           { Name = "SessionToken", Selector = "$.Credentials.SessionToken", Type = "String" }
#         ]
#       },
#       # NEW: Invoke SES Lambda for each alert (use loop if multiple)
#       {
#         name           = "SendAlertViaSES"
#         action         = "aws:invokeLambdaFunction"
#         timeoutSeconds = 60
#         maxAttempts    = 1
#         onFailure      = "Continue" # or Abort

#         inputs = {
#           FunctionName = "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert" # ← your Lambda ARN
#           Payload      = "{{ CheckAllBudgets.alerts }}"                                           # assumes your script outputs JSON with "alerts" array
#           # If single alert, hard-code or use "{{ CheckAllBudgets.outputField }}"
#         }

#         outputs = [
#           { Name = "LambdaResponse", Selector = "$.Payload", Type = "String" }
#         ]
#       },

#       {
#         name   = "CheckAllBudgets"
#         action = "aws:executeScript"
#         inputs = {
#           Runtime = "python3.11"
#           Handler = "handler"

#           InputPayload = {
#             AccessKeyId     = "{{ AssumeManagementRole.AccessKeyId }}"
#             SecretAccessKey = "{{ AssumeManagementRole.SecretAccessKey }}"
#             SessionToken    = "{{ AssumeManagementRole.SessionToken }}"
#             MemberRoleName  = "{{ MemberRoleName }}"

#             budgets_to_check = [
#               for k, v in local.accounts : {
#                 budget_name     = v.budget_name
#                 threshold       = v.alert_threshold
#                 sns_topic_arn   = v.sns_topic_arn
#                 linked_accounts = length(v.linked_accounts) > 0 ? v.linked_accounts : [v.account_id]
#               }
#             ]
#           }

#           Script = <<EOT

# import boto3
# import json
# import logging

# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# def handler(event, context):

#     results = []
#     alerts = []

#     # Management account credentials — ALWAYS use these to read the budget

#     mgmt_creds = {

#         'aws_access_key_id': event['AccessKeyId'],

#         'aws_secret_access_key': event['SecretAccessKey'],

#         'aws_session_token': event['SessionToken']

#     }



#     # Always use management account session to read budget

#     mgmt_session = boto3.Session(**mgmt_creds)

#     budgets_client = mgmt_session.client('budgets')

#     sns_client     = mgmt_session.client('sns')

#     sts_client     = mgmt_session.client('sts')



#     # Get management account ID

#     management_account_id = sts_client.get_caller_identity()['Account']



#     for cfg in event['budgets_to_check']:

#         budget_name = cfg['budget_name']

#         threshold   = float(cfg['threshold'])

#         sns_topic   = cfg['sns_topic_arn']

#         accounts    = [str(a) for a in cfg['linked_accounts']]



#         try:

#             # ALWAYS read the budget from the management account

#             resp = budgets_client.describe_budget(

#                 AccountId=management_account_id,

#                 BudgetName=budget_name

#             )

#             actual = float(resp['Budget']['CalculatedSpend']['ActualSpend']['Amount'])

#             limit  = float(resp['Budget']['BudgetLimit']['Amount'])

#             pct    = (actual / limit * 100) if limit > 0 else 0



#             for acc_id in accounts:

#                 status = "OK"

#                 if pct >= threshold:

#                     status = "ALERT_SENT"

#                     payload = {

#                         "offending_account_id": acc_id,           # REAL linked account

#                         "budget_name": budget_name,

#                         "actual_spend_usd": round(actual, 2),

#                         "budget_limit_usd": round(limit, 2),

#                         "percent_used": round(pct, 2),

#                         "threshold_percent": threshold,

#                         "subject": f"Budget Alert - Account {acc_id} exceeded {threshold}%"

#                     }

#                     # sns_client.publish(

#                     #     TopicArn=sns_topic,

#                     #     Subject=payload["subject"],

#                     #     Message=json.dumps(payload)

#                     # )

#                     # CORRECT — THIS IS THE ONLY WAY

#                     # sns_client.publish(

#                     #       TopicArn=sns_topic,

#                     #       Message=json.dumps(payload)   # ← ONLY Message

#                     #   )

#                     # logger.info(f"ALERT SENT for offending account {acc_id}")


#                 results.append({

#                     "account_id": acc_id,

#                     "budget_name": budget_name,

#                     "percent_used": round(pct, 2),

#                     "status": status

#                 })



#         except Exception as e:

#             for acc_id in accounts:

#                 results.append({

#                     "account_id": acc_id,

#                     "budget_name": budget_name,

#                     "status": "ERROR",

#                     "error": str(e)

#                 })



#     return {"results": results}
#     return {"alerts": alerts}

# EOT
#         }
#       }
#     ]
#   })
# }


#   outputs = [
#     { Name = "results", Selector = "$.results", Type = "String" },
#     { Name = "alerts", Selector = "$.alerts", Type = "String" }
#   ]
# },
# # NEW: Invoke SES Lambda for all alerts
# {
#   name           = "InvokeSESLambda"
#   action         = "aws:invokeLambdaFunction"
#   timeoutSeconds = 120
#   maxAttempts    = 3
#   onFailure      = "Continue"

#   inputs = {
#     FunctionName   = "arn:aws:lambda:us-east-1:224761220970:function:budget_update_gha_alert"
#     InvocationType = "Event"

#     InputPayload = {
#       InputPayload = {
#         alerts = "[{{ CheckAllBudgets.alerts | replace('\"', '\\\"') }}]" # complex, not recommended
#       }
# execution_id = "{{ automation:EXECUTION_ID }}"
# alerts = [
#   {
#     offending_account_id = "752338767189",
#     budget_name          = "TestBudget",
#     actual_spend_usd     = 4,
#     budget_limit_usd     = 5,
#     percent_used         = 80,
#     threshold_percent    = 80,
#     subject              = "TEST Budget Alert"
#   }
# ]

#       }



#     ]

#   })

# }




# resource "aws_ssm_document" "check_budget_and_alert" {
#   name            = "budget_update_gha_alert"
#   document_type   = "Automation"
#   document_format = "JSON"

#   content = jsonencode({
#     schemaVersion = "0.3"
#     description   = "Check one or more budgets and publish JSON alerts to SNS"

#     parameters = {
#       BudgetsToCheck = {
#         type        = "String"
#         description = "JSON string of array of budgets to check"
#         default     = "[]"
#       }
#       AutomationAssumeRole = {
#         type        = "String"
#         description = "(Optional) IAM role for Automation to assume"
#         default     = "arn:aws:iam::224761220970:role/AWS-SystemsManager-AutomationAdministrationRole"
#       }
#       MemberRoleName = {
#         type    = "String"
#         default = "budget_assume_role"
#       }
#       BudgetName = {
#         type        = "StringList"
#         description = "Name of the AWS Budget to check"
#         default     = [for item in local.csvfld : item.BudgetName]
#       }
#       ThresholdPercent = {
#         type        = "String"
#         description = "Budget threshold percentage to trigger alert"
#         default     = "80"
#       }
#       SNSTopicArn = {
#         type    = "String"
#         default = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
#       }
#     }

#     mainSteps = [
#       {
#         name   = "AssumeManagementRole"
#         action = "aws:executeAwsApi"
#         inputs = {
#           Service         = "sts"
#           Api             = "AssumeRole"
#           RoleArn         = "{{ AutomationAssumeRole }}"
#           RoleSessionName = "BudgetCheckSession"
#         }
#         outputs = [
#           { Name = "AccessKeyId", Selector = "$.Credentials.AccessKeyId", Type = "String" },
#           { Name = "SecretAccessKey", Selector = "$.Credentials.SecretAccessKey", Type = "String" },
#           { Name = "SessionToken", Selector = "$.Credentials.SessionToken", Type = "String" }
#         ]
#       },

#       {
#         name   = "CheckAllBudgets"
#         action = "aws:executeScript"
#         inputs = {
#           Runtime = "python3.11"
#           Handler = "handler"

#           InputPayload = {
#             # Pass the assumed role credentials
#             AccessKeyId     = "{{ AssumeManagementRole.AccessKeyId }}"
#             SecretAccessKey = "{{ AssumeManagementRole.SecretAccessKey }}"
#             SessionToken    = "{{ AssumeManagementRole.SessionToken }}"

#             # Keep other inputs
#             MemberRoleName = "{{ MemberRoleName }}"

#             # Budgets must be passed from checker Lambda
#             BudgetsToCheck = "{{ BudgetsToCheck }}" # JSON string
#             SNSTopicArn    = "{{ SNSTopicArn }}"
#           }
#           Script = <<EOT
# import boto3
# import json
# import logging

# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# def handler(event, context):
#     results = []

#     # Management account credentials — ALWAYS use these to read the budget

#     mgmt_creds = {

#         'aws_access_key_id': event['AccessKeyId'],

#         'aws_secret_access_key': event['SecretAccessKey'],

#         'aws_session_token': event['SessionToken']

#     }



#     # Always use management account session to read budget

#     mgmt_session = boto3.Session(**mgmt_creds)

#     budgets_client = mgmt_session.client('budgets')

#     sns_client     = mgmt_session.client('sns')

#     sts_client     = mgmt_session.client('sts')

#     # Parse budgets from input (passed as JSON string)
#     budgets_str = event.get('BudgetsToCheck', '[]')
#     try:
#         budgets = json.loads(budgets_str)
#     except Exception as e:
#         logger.error(f"Invalid BudgetsToCheck JSON: {str(e)}")
#         return {"status": "invalid_input"}

#     if not budgets:
#         logger.info("No budgets provided in input")
#         return {"status": "no_budgets"}

#     sns_topic = event.get('SNSTopicArn')
#     if not sns_topic:
#         logger.error("No SNSTopicArn provided")
#         return {"status": "missing_sns"}

#     budgets_client = boto3.client('budgets')
#     sns_client = boto3.client('sns')
#     account_id = boto3.client('sts').get_caller_identity()['Account']

#     for cfg in budgets:
#         name = cfg.get('budget_name') or cfg.get('BudgetName')
#         thresh = float(cfg.get('threshold') or cfg.get('ThresholdPercent') or 80.0)
#         accounts = cfg.get('linked_accounts', []) or []

#         if not name:
#             logger.warning("Missing budget_name – skipping")
#             continue

#         try:
#             resp = budgets_client.describe_budget(AccountId=account_id, BudgetName=name)
#             actual = float(resp['Budget']['CalculatedSpend']['ActualSpend']['Amount'])
#             limit = float(resp['Budget']['BudgetLimit']['Amount'])
#             pct = round(actual / limit * 100, 2) if limit > 0 else 0.0

#             logger.info(f"Budget '{name}': {pct:.2f}% used")

#             if pct >= thresh:
#                 for acc in accounts:
#                     payload = {
#                         "offending_account_id": acc,
#                         "budget_name": name,
#                         "actual_spend_usd": round(actual, 2),
#                         "budget_limit_usd": round(limit, 2),
#                         "percent_used": pct,
#                         "threshold_percent": thresh
#                     }

#                     try:
#                         sns_client.publish(
#                             TopicArn=sns_topic,
#                             Message=json.dumps(payload),
#                             MessageStructure='json'  # critical for JSON delivery
#                         )
#                         logger.info(f"JSON alert published for account {acc} - {name}")
#                     except Exception as pub_err:
#                         logger.error(f"SNS publish failed: {str(pub_err)}")

#                     results.append({
#                         "account_id": acc,
#                         "budget_name": name,
#                         "percent_used": pct,
#                         "status": "ALERT_SENT"
#                     })
#             else:
#                 results.append({
#                     "budget_name": name,
#                     "percent_used": pct,
#                     "status": "OK"
#                 })

#         except Exception as e:
#             logger.error(f"Budget check failed for {name}: {str(e)}")
#             results.append({"budget_name": name, "status": "error", "error": str(e)})

#     return {"status": "complete", "results": results}
# EOT
#         }
#       }
#     ]
#   })
# }


#     mainSteps = [
#       {
#         name   = "AssumeManagementRole"
#         action = "aws:executeAwsApi"
#         isEnd  = false
#         inputs = {
#           Service         = "sts"
#           Api             = "AssumeRole"
#           RoleArn         = "{{ AutomationAssumeRole }}"
#           RoleSessionName = "BudgetCheckSession"
#         }
#         outputs = [
#           { Name = "AccessKeyId", Selector = "$.Credentials.AccessKeyId", Type = "String" },
#           { Name = "SecretAccessKey", Selector = "$.Credentials.SecretAccessKey", Type = "String" },
#           { Name = "SessionToken", Selector = "$.Credentials.SessionToken", Type = "String" }
#         ]
#       },

#       {
#         name   = "CheckAllBudgets"
#         action = "aws:executeScript"
#         isEnd  = true
#         inputs = {
#           Runtime = "python3.11"
#           Handler = "handler"

#           # Critical: Pass the temp creds from the previous step
#           InputPayload = {
#             AccessKeyId     = "{{ AssumeManagementRole.AccessKeyId }}"
#             SecretAccessKey = "{{ AssumeManagementRole.SecretAccessKey }}"
#             SessionToken    = "{{ AssumeManagementRole.SessionToken }}"

#             # Keep other inputs (add BudgetsToCheck if needed)
#             MemberRoleName = "{{ MemberRoleName }}"
#             BudgetsToCheck = "{{ BudgetsToCheck }}" # JSON string from checker Lambda
#             SNSTopicArn    = "{{ SNSTopicArn }}"
#           }

#           Script = <<EOT
# # import boto3
# # import json
# # import logging

# # logger = logging.getLogger()
# # logger.setLevel(logging.INFO)

# # def handler(event, context):
# #     results = []

# #     # Use the passed temporary credentials
# #     creds = {
# #         'aws_access_key_id': event['AccessKeyId'],
# #         'aws_secret_access_key': event['SecretAccessKey'],
# #         'aws_session_token': event['SessionToken']
# #     }

# #     # Create authenticated session
# #     session = boto3.Session(**creds)

# #     budgets_client = session.client('budgets')
# #     sns_client     = session.client('sns')
# #     sts_client     = session.client('sts')

# #     # Now this will succeed
# #     management_account_id = sts_client.get_caller_identity()['Account']

# #     # Load budgets from input (passed as JSON string)
# #     budgets_str = event.get('BudgetsToCheck', '[]')
# #     try:
# #         budgets_to_check = json.loads(budgets_str)
# #     except Exception as e:
# #         logger.error(f"Invalid BudgetsToCheck JSON: {str(e)}")
# #         return {"status": "invalid_input"}

# #     if not budgets_to_check:
# #         logger.info("No budgets provided")
# #         return {"status": "no_budgets"}

# #     sns_topic = event.get('SNSTopicArn')
# #     if not sns_topic:
# #         logger.error("No SNSTopicArn provided")
# #         return {"status": "missing_sns"}

# #     for cfg in budgets_to_check:
# #         budget_name = cfg.get('budget_name') or cfg.get('BudgetName')
# #         threshold   = float(cfg.get('threshold') or cfg.get('ThresholdPercent') or 80.0)
# #         accounts    = [str(a) for a in cfg.get('linked_accounts', [])]

# #         if not budget_name:
# #             logger.warning("Missing budget_name – skipping")
# #             continue

# #         try:
# #             resp = budgets_client.describe_budget(
# #                 AccountId=management_account_id,
# #                 BudgetName=budget_name
# #             )

# #             actual = float(resp['Budget']['CalculatedSpend']['ActualSpend']['Amount'])
# #             limit  = float(resp['Budget']['BudgetLimit']['Amount'])
# #             pct = round((actual / limit * 100), 2) if limit > 0 else 0.0

# #             logger.info(f"Budget '{budget_name}': {pct:.2f}% used")

# #             if pct >= threshold:
# #                 for acc_id in accounts:
# #                     payload = {
# #                         "offending_account_id": acc_id,
# #                         "budget_name": budget_name,
# #                         "actual_spend_usd": round(actual, 2),
# #                         "budget_limit_usd": round(limit, 2),
# #                         "percent_used": pct,
# #                         "threshold_percent": threshold
# #                     }

# #                     try:
# #                         sns_client.publish(
# #                             TopicArn=sns_topic,
# #                             Message=json.dumps(payload),
# #                             MessageStructure='json'
# #                         )
# #                         logger.info(f"Alert published for account {acc_id} - {budget_name}")
# #                     except Exception as pub_err:
# #                         logger.error(f"SNS publish failed: {str(pub_err)}")

# #                     results.append({
# #                         "account_id": acc_id,
# #                         "budget_name": budget_name,
# #                         "percent_used": pct,
# #                         "status": "ALERT_SENT"
# #                     })
# #             else:
# #                 results.append({
# #                     "budget_name": budget_name,
# #                     "percent_used": pct,
# #                     "status": "OK"
# #                 })

# #         except Exception as e:
# #             logger.error(f"Error checking budget '{budget_name}': {str(e)}")
# #             results.append({
# #                 "budget_name": budget_name,
# #                 "status": "ERROR",
# #                 "error": str(e)
# #             })

# #     return {"status": "complete", "results": results}
# # EOT
# #         }
# #       }
# #     ]
# #   })
# # }

# import boto3
# import json
# import logging

# # ── Logger setup ── (must come first!)
# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# def handler(event, context):
#     logger.info("Full event received:\n" + json.dumps(event, indent=2))

#     key = 'BudgetsToCheck'  # or 'budgets_to_check' if you renamed it

#     if key not in event:
#         logger.error(f"Missing required key: {key}")
#         logger.info(f"Available event keys: {list(event.keys())}")
#         return {"results": [], "error": f"Missing {key}"}

#     raw_budgets = event[key]
#     logger.info(f"Raw BudgetsToCheck value (type={type(raw_budgets)}): {raw_budgets}")

#     if isinstance(raw_budgets, str):
#         try:
#             budgets_list = json.loads(raw_budgets)
#             logger.info(f"Parsed {len(budgets_list)} budget configs")
#         except json.JSONDecodeError as e:
#             logger.error(f"JSON parse failed: {str(e)}")
#             logger.info(f"Invalid raw value: {raw_budgets}")
#             return {"results": [], "error": "Invalid JSON in BudgetsToCheck"}
#     elif isinstance(raw_budgets, list):
#         budgets_list = raw_budgets
#     else:
#         logger.error(f"Unexpected type for BudgetsToCheck: {type(raw_budgets)}")
#         return {"results": [], "error": "BudgetsToCheck wrong type"}

#     if not isinstance(budgets_list, list):
#         logger.error("BudgetsToCheck did not resolve to a list")
#         return {"results": [], "error": "BudgetsToCheck not a list after parsing"}

#     results = []

#     if len(accounts) == 1:
#       offending_acc = accounts[0]
#       payload["offending_account_id"] = offending_acc
#       payload["subject"] = f"Budget Alert - Account {offending_acc} exceeded {threshold}%"
#       # publish
# else:
#     # fallback to aggregate or skip/log warning
#     logger.warning(f"Budget {budget_name} covers multiple accounts ({accounts}) - cannot pinpoint offender")
#     # Management credentials setup (your existing code)
#     mgmt_creds = {
#         'aws_access_key_id': event['AccessKeyId'],
#         'aws_secret_access_key': event['SecretAccessKey'],
#         'aws_session_token': event['SessionToken']
#     }

#     mgmt_session = boto3.Session(**mgmt_creds)
#     budgets_client = mgmt_session.client('budgets')
#     sns_client    = mgmt_session.client('sns')
#     sts_client    = mgmt_session.client('sts')

#     management_account_id = sts_client.get_caller_identity()['Account']

#     for cfg in budgets_list:
#         try:
#             budget_name = cfg['budget_name']
#             threshold   = float(cfg['threshold'])
#             sns_topic   = cfg['sns_topic_arn']
#             accounts    = [str(a) for a in cfg.get('linked_accounts', [])]

#             # ... rest of your budget-checking logic unchanged ...
#             # describe_budget, calculate pct, publish alerts, append to results

#         except Exception as e:
#             logger.exception(f"Error processing budget config: {cfg}")
#             # your error handling / results append

#     logger.info(f"Automation complete. Processed {len(results)} account-budget pairs.")
#     return {"results": results}

# EOT
#         }
#       }
#     ]
#   })
# }




# resource "aws_iam_policy" "assume_role_policy" {
#   name        = "AssumePolicyBudgets"
#   description = "Allows assuming roles in member accounts"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect   = "Allow",
#         Action   = "sts:AssumeRole",
#         Resource = "arn:aws:iam::752338767189:role/OrganizationAccountAccessRole"
#       }
#     ]
#   })


# resource "aws_iam_role" "orgzn_role" {
#   name = "OrgznAssumeRoleForBudgets"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           "Service" = "ssm.amazonaws.com",
#         },
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }
# resource "aws_iam_role_policy_attachment" "attach_assume_role_policy" {
#   role       = aws_iam_role.orgzn_role.name
#   policy_arn = aws_iam_policy.assume_role_policy.arn
# }

#Required role in management account
# resource "aws_iam_role" "budget_checker" {
#   name = "OrganizationBudgetCheckerRole"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect    = "Allow"
#       Principal = { Service = "ssm.amazonaws.com" }
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy" "allow_assume_member" {
#   role = aws_iam_role.budget_checker.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect   = "Allow"
#       Action   = "sts:AssumeRole"
#       Resource = "arn:aws:iam::752338767189:role/budget_assume_role"
#     }]
#   })
# }

# variable "budgets" {
#   description = "List of budgets to monitor"
#   type = list(object({
#     BudgetName       = string
#     ThresholdPercent = number
#     # you can add more fields later, e.g. SNSTopicArn, LinkedAccounts, etc.
#   }))
#   value = jsonencode([
#     {
#       BudgetName       = "ABC Operations PROD Account Overall Budget"
#       ThresholdPercent = 80
#     },
#     {
#       BudgetName       = "ABC Operations DEV Account Overall Budget"
#       ThresholdPercent = 80
#     },
#     {
#       BudgetName       = "ABC Operations QA Account Overall Budget"
#       ThresholdPercent = 80
#     },
#     # ... add 100+ entries here ...
#   ])
# }


resource "aws_ssm_parameter" "budget_monitoring_list" {
  name        = "/budget/monitoring/list"
  description = "JSON list of budgets to monitor"
  type        = "String"
  value = jsonencode([
    {
      BudgetName       = "ABC Operations PROD Account Overall Budget"
      ThresholdPercent = 80
    },
    {
      BudgetName       = "ABC Operations DEV Account Overall Budget"
      ThresholdPercent = 80
    },
    {
      BudgetName       = "ABC Operations QA Account Overall Budget"
      ThresholdPercent = 80
    }
    # Add all your budgets here...
  ])
}

resource "aws_cloudwatch_event_rule" "budget_threshold" {
  name        = "budget-threshold-exceeded"
  description = "Trigger SSM on AWS Budgets threshold breach"

  event_pattern = jsonencode({
    source      = ["budgets.amazonaws.com"]
    detail-type = ["AWS Budgets Notification"]
    detail = {
      notification = {
        type = ["ACTUAL", "FORECASTED"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "ssm_automation" {
  rule      = aws_cloudwatch_event_rule.budget_threshold.name
  target_id = "ssm-budget-trigger"
  arn       = "arn:aws:lambda:us-east-1:224761220970:function:ssm-budget-trigger" #"arn:aws:ssm:us-east-1:224761220970:automation-definition/budget_update_gha_alert" # or just document name if default version

  role_arn = aws_iam_role.eventbridge_to_ssm.arn

  input_transformer {
    input_paths = {
      budgetName = "$.detail.notification.budgetName"
      threshold  = "$.detail.notification.threshold"
      # add others as needed
    }

    input_template = jsonencode({
      BudgetName       = [" ABC Operations PROD Account Overall Budget"]
      ThresholdPercent = ["80"]
      # SNSTopicArn etc.
    })
  }
}

# IAM role for EventBridge → SSM
resource "aws_iam_role" "eventbridge_to_ssm" {
  # ... assume role policy for events.amazonaws.com
  name = "event-bridge-to-SSMRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ssm_start" {
  role = aws_iam_role.eventbridge_to_ssm.id

  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = "arn:aws:lambda:us-east-1:224761220970:function:ssm-budget-trigger"
    }]
  })
}

