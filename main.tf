locals {
  csvfld = csvdecode(file("./csvdata.csv"))
  accounts = {
    for row in local.csvfld :
    "${row.AccountId}_${row.BudgetName}" => {
      account_id      = row.AccountId
      budget_name     = row.BudgetName
      budget_amount   = row.BudgetAmount
      alert_threshold = row.Alert1Threshold
      alert_trigger   = row.Alert1Trigger
      sns_topic_arn   = row.SNSTopicArn
      linked_accounts = contains(keys(row), "linked_accounts") ? jsondecode(row.linked_accounts) : []

    }

  }



  csv_hash = filemd5("./csvdata.csv")
}


# resource "aws_budgets_budget" "budget_notification" {
#   for_each          = { for BudgetName in local.csvfld : BudgetName.BudgetName => BudgetName }
#   name              = each.value.BudgetName
#   budget_type       = "COST"
#   limit_amount      = each.value.BudgetAmount
#   limit_unit        = "USD"
# #   time_period_start = each.value.StartMonth
# #   time_period_end   = each.value.EndMonth
#   time_unit         = "MONTHLY"

#   notification {
#     comparison_operator        = "GREATER_THAN"
#     threshold                  = each.value.Alert1Threshold
#     threshold_type             = "PERCENTAGE"
#     notification_type          = each.value.Alert1Trigger
#     # subscriber_email_addresses = [each.value.Alert1Emails]
#     subscriber_sns_topic_arns  = ["arn:aws:sns:us-east-1:224761220970:budget-updates-topic"]


#   }
# }
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
        "Action" : "ses:SendEmail",
        "Resource" : "*"
      },
      {
        "Sid" : "AllowSSMAutomationExecution",
        "Effect" : "Allow",
        "Action" : [
          "budgets:DescribeBudget",
          "budgets:ViewBudget",
          "ssm:GetParameter"

        ]

        "Resource" : [
          "arn:aws:ssm:us-east-1:224761220970:parameter/budgets/default/*",
          "arn:aws:ssm:us-east-1:224761220970:automation-definition/budget_update_gha_alert"
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
          "budgets:ViewBudget"


        ],
        "Resource" : [
          "*"

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
      }
      # {
      #   "Effect" : "Allow",
      #   "Action" : "ssm:StartAutomationExecution",
      #   "Resource" : [
      #     # "arn:aws:ssm:us-east-1:224761220970:automation-definition/budget_update_gha_alert:*",
      #     "arn:aws:ssm:us-east-1:224761220970:automation-definition/budget_update_gha_alert:$DEFAULT"
      #   ]
      # }
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

  runtime = "python3.12"
  timeout = 180

  environment {
    variables = {
      SENDER_EMAIL     = "abbysac@gmail.com"
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
  function_name = aws_lambda_function.test_lambda.function_name #"budget_update_gha_alert"
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
  topic_arn  = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
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






##Use the aws_budgets_budget resource from the Terraform Registry to create budgets, 
##leveraging the for_each meta-argument for iteration. In main.tf, add:

resource "aws_budgets_budget" "budget_notification" {
  for_each     = local.accounts
  name         = each.value.budget_name
  budget_type  = "COST"
  limit_amount = each.value.budget_amount
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "cost_filter" {
    for_each = contains(keys(each.value), "linked_accounts") && length(each.value.linked_accounts) > 0 ? [2] : []
    content {
      name   = "LinkedAccount"
      values = each.value.linked_accounts
    }
  }


  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = each.value.alert_threshold
    threshold_type            = "PERCENTAGE"
    notification_type         = each.value.alert_trigger
    subscriber_sns_topic_arns = [each.value.sns_topic_arn]
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
          "organizations:ListAccountsForParent"

        ]
        Resource = [

          "arn:aws:budgets::224761220970:budget/ABC Operations DEV Account Overall Budget",
          "arn:aws:budgets::224761220970:budget/ABC Operations PROD Account Overall Budget",
          "arn:aws:budgets::224761220970:budget/ABC Operations QA Account Overall Budget",
          "arn:aws:sns:us-east-1:224761220970:budget-updates-topic",
          "arn:aws:iam::224761220970:role/GitHubActionsOIDCRole"
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
locals {
  active_accounts = [
    for account in data.aws_organizations_organization.org.accounts :
    account.id
    if account.status == "ACTIVE" && account.id != data.aws_organizations_organization.org.master_account_id
  ]
  all_accounts = [
    for account in data.aws_organizations_organization.org.accounts :
    account.id
    if account.status == "ACTIVE"
  ]
}

# Output for debugging
output "active_linked_accounts" {
  value = local.active_accounts
}

output "all_active_accounts" {
  value = local.all_accounts
}


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
      Message = {
        type    = "String"
        default = "this is to notify you that you have exceeded your budget threshold"
      }
      BudgetName = {
        type    = "StringList"
        default = [for item in local.csvfld : item.BudgetName] #"ABC Operations PROD Account Overall Budget" #"ABC Operations DEV Account Overall Budget"
      }
      BudgetThresholdPercent = {
        type    = "String"
        default = "80.0" # Low threshold for testing
      }
      AccountId = {
        type    = "String"
        default = "752338767189"
      }
      # alertThreshold = {
      #   type    = "String"
      #   default = tostring(var.alert_threshold)
      # }
      alertTrigger = {
        type    = "String"
        default = "ACTUAL"
      }
    }

    mainSteps = [
      {
        name   = "ConstructMessage"
        action = "aws:executeScript"
        inputs = {
          Runtime = "python3.8"
          Handler = "construct_message"
          Script  = <<-EOT
            import json
            def construct_message(inputs, context):
                message = {
                    "budgetName": inputs["BudgetName"],
                    "actualSpend": float(inputs["ActualSpend"]),
                    "budgetLimit": float(inputs["BudgetLimit"]),
                    "accountId": inputs["AccountId"],
                    "alertType": inputs["AlertType"],
                    "threshold": float(inputs["Threshold"]),
                    "environment": "prod",
                    "percentage_used": (float(inputs["ActualSpend"]) / float(inputs["BudgetLimit"]) * 100) if float(inputs["BudgetLimit"]) > 0 else 0.0
                }
                return {"message": json.dumps(message)}
          EOT
          InputPayload = {
            BudgetName  = "{{ BudgetName }}"
            ActualSpend = "{{ ActualSpend }}"
            BudgetLimit = "{{ BudgetLimit }}"
            AccountId   = "{{ AccountId }}"
            AlertType   = "{{ AlertType }}"
            Threshold   = "{{ Threshold }}"
          }
        }
        outputs = [
          {
            Name     = "message"
            Selector = "$.Payload.message"
            Type     = "String"
          }
        ]
      },
      {
        name   = "PublishToSNS"
        action = "aws:executeAwsApi"
        inputs = {
          Service  = "sns"
          Api      = "Publish"
          TopicArn = "{{ TopicArn }}"
          Message  = "{{ ConstructMessage.message }}"
          MessageAttributes = {
            budgetName = {
              DataType    = "String"
              StringValue = "{{ BudgetName }}"
            }
            alertType = {
              DataType    = "String"
              StringValue = "{{ AlertType }}"
            }
          }
        }
        onFailure = "step:LogError"
        outputs = [
          {
            Name     = "MessageId"
            Selector = "$.MessageId"
            Type     = "String"
          }
        ]
      },
      {
        name   = "LogResult"
        action = "aws:executeScript"
        inputs = {
          Runtime = "python3.8"
          Handler = "log_result"
          Script  = <<-EOT
            def log_result(inputs, context):
                print(f"SNS Message Published. MessageId: {inputs['MessageId']}")
                return {"status": "Success", "messageId": inputs["MessageId"]}
          EOT
          InputPayload = {
            MessageId = "{{ PublishToSNS.MessageId }}"
          }
        }
        onFailure = "step:LogError"
      },
      {
        name   = "LogError"
        action = "aws:executeScript"
        isEnd  = true
        inputs = {
          Runtime = "python3.8"
          Handler = "log_error"
          Script  = <<-EOT
            def log_error(inputs, context):
                print("Failed to publish SNS message")
                return {"status": "Failure"}
          EOT
        }
      }
    ]
    outputs = [
      {
        Name     = "MessageId"
        Selector = "$.PublishToSNS.MessageId"
        Type     = "String"
      },
      {
        Name     = "Status"
        Selector = "$.LogResult.status"
        Type     = "String"
      }
    ]
  })
}


variable "aws_region" {
  type    = string
  default = "us-east-1"
}


# Null resource for each account
resource "null_resource" "trigger_ssm_on_csv_change" {
  for_each = {
    for key, account in local.accounts :
    key => account
    if account.budget_amount >= account.alert_threshold && account.alert_trigger == "Enabled"
  }

  triggers = {
    csv_hash         = local.csv_hash
    threshold_status = "${each.value.budget_amount}_${each.value.alert_threshold}"
  }

  provisioner "local-exec" {
    command = <<EOT
      echo Debug: TargetAccountId=${each.value.account_id}, BudgetName=${each.value.budget_name}, BudgetAmount=${each.value.budget_amount}, AlertThreshold=${each.value.alert_threshold}
      aws ssm start-automation-execution --document-name "budget_update_gha_alert" --region "${var.aws_region}" --parameters "{\"TargetAccountId\":\"${each.value.account_id}\",\"BudgetName\":\"${each.value.budget_name}\",\"BudgetAmount\":\"${each.value.budget_amount}\",\"AlertThreshold\":\"${each.value.alert_threshold}\"}" || echo SSM execution failed: %ERRORLEVEL%
    EOT
  }

  depends_on = [aws_ssm_document.invoke_central_lambda]
}