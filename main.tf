locals {
  csvfld = csvdecode(file("./csvdata.csv"))
  accounts = {
    for row in local.csvfld :
    "${row.AccountId}_${row.BudgetName}" => {
      # "${row.linked_accounts}_${row.BudgetName}" => {
      account_id = row.AccountId
      # linked_accounts = row.linked_accounts
      budget_name     = row.BudgetName
      budget_amount   = row.BudgetAmount
      alert_threshold = row.Alert1Threshold
      alert_trigger   = row.Alert1Trigger
      sns_topic_arn   = row.SNSTopicArn
      email           = trim(row.email, " ") # safe even if empty
      # linked_accounts = contains(keys(row), "linked_accounts") ? jsondecode(row.linked_accounts) : []
      # Account_id = contains(keys(row), "account_id") ? jsondecode(row.account_id) : []
      linked_accounts = try(
        jsondecode(row.linked_accounts),
        compact(split(",", replace(row.linked_accounts, " ", ""))),
        length(trimspace(coalesce(row.linked_accounts, ""))) == 12 ? [trimspace(row.linked_accounts)] : [],
        []
      )

    }

  }



  csv_hash = filemd5("./csvdata.csv")
}

output "csv_keys" {
  value = [for row in local.csvfld : keys(row)]
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

  runtime = "python3.11"
  timeout = 180

  # environment {
  #   variables = {
  #     SENDER_EMAIL     = "abbysac@gmail.com"
  #     RECIPIENT_EMAILS = "camleous@yahoo.com"
  #   }
  # }
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

  # dynamic "cost_filter" {
  #   for_each = contains(keys(each.value), "member_account_ids") && length(each.value.member_account_ids) > 0 ? [2] : []
  #   content {
  #     name   = "memberAccountIds"
  #     values = each.value.member_account_ids
  #   }
  # }

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



# resource "aws_ssm_document" "invoke_central_lambda" {
#   name          = "budget_update_gha_alert"
# document_type = "Automation"
# schemaVersion: '0.3'
resource "aws_ssm_document" "check_budget_and_alert" {
  name          = "budget_update_gha_alert"
  document_type = "Automation"

  content = jsonencode({
    schemaVersion = "0.3"
    description   = "Assume a role, check AWS Budgets, and publish to SNS if threshold exceeded."
    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        description = "(Optional) IAM role for Automation to assume"
        default     = "arn:aws:iam::224761220970:role/AWS-SystemsManager-AutomationAdministrationRole"
      }
      MemberRoleName = {
        type    = "String"
        default = "budget_assume_role"
      }
      TargetRoleArn = {
        type        = "String"
        description = "ARN of the IAM Role to assume in the target account"
        default     = "arn:aws:iam::224761220970:role/AWS-SystemsManager-AutomationAdministrationRole"
      }
      BudgetName = {
        type        = "StringList"
        description = "Name of the AWS Budget to check"
        default     = [for item in local.csvfld : item.BudgetName]
      }
      BudgetEmail = {
        type        = "StringList"
        description = "Name of the AWS Budget to check"
        default     = [for item in local.csvfld : item.email]
      }
      ThresholdPercent = {
        type        = "String"
        description = "Budget threshold percentage to trigger alert"
        default     = "80"
      }
      SNSTopicArn = {
        type        = "String"
        description = "SNS topic ARN to publish the alert to"
        default     = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
      }
    }
    mainSteps = [
      {
        name   = "AssumeManagementRole"
        action = "aws:executeAwsApi"
        inputs = {
          Service         = "sts"
          Api             = "AssumeRole"
          RoleArn         = "{{ AutomationAssumeRole }}"
          RoleSessionName = "BudgetCheck"
        }
        outputs = [
          { Name = "AccessKeyId", Selector = "$.Credentials.AccessKeyId", Type = "String" },
          { Name = "SecretAccessKey", Selector = "$.Credentials.SecretAccessKey", Type = "String" },
          { Name = "SessionToken", Selector = "$.Credentials.SessionToken", Type = "String" }
        ]
      },

      {
        name   = "CheckAllBudgets"
        action = "aws:executeScript"
        inputs = {
          Runtime = "python3.11"
          Handler = "handler"

          InputPayload = {
            AccessKeyId     = "{{ AssumeManagementRole.AccessKeyId }}"
            SecretAccessKey = "{{ AssumeManagementRole.SecretAccessKey }}"
            SessionToken    = "{{ AssumeManagementRole.SessionToken }}"
            MemberRoleName  = "{{ MemberRoleName }}"

            budgets_to_check = [
              for k, v in local.accounts : {
                budget_name     = v.budget_name
                threshold       = v.alert_threshold
                sns_topic_arn   = v.sns_topic_arn
                linked_accounts = length(v.linked_accounts) > 0 ? v.linked_accounts : [v.account_id]
              }
            ]
          }

          Script = <<EOT
import boto3
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    results = []

    # Management account credentials — ALWAYS use these to read the budget
    mgmt_creds = {
        'aws_access_key_id': event['AccessKeyId'],
        'aws_secret_access_key': event['SecretAccessKey'],
        'aws_session_token': event['SessionToken']
    }

    # Always use management account session to read budget
    mgmt_session = boto3.Session(**mgmt_creds)
    budgets_client = mgmt_session.client('budgets')
    sns_client     = mgmt_session.client('sns')
    sts_client     = mgmt_session.client('sts')

    # Get management account ID
    management_account_id = sts_client.get_caller_identity()['Account']

    for cfg in event['budgets_to_check']:
        budget_name = cfg['budget_name']
        threshold   = float(cfg['threshold'])
        sns_topic   = cfg['sns_topic_arn']
        accounts    = [str(a) for a in cfg['linked_accounts']]

        try:
            # ALWAYS read the budget from the management account
            resp = budgets_client.describe_budget(
                AccountId=management_account_id,
                BudgetName=budget_name
            )
            actual = float(resp['Budget']['CalculatedSpend']['ActualSpend']['Amount'])
            limit  = float(resp['Budget']['BudgetLimit']['Amount'])
            pct    = (actual / limit * 100) if limit > 0 else 0

            for acc_id in accounts:
                status = "OK"
                if pct >= threshold:
                    status = "ALERT_SENT"
                    payload = {
                        "offending_account_id": acc_id,           # REAL linked account
                        "budget_name": budget_name,
                        "actual_spend_usd": round(actual, 2),
                        "budget_limit_usd": round(limit, 2),
                        "percent_used": round(pct, 2),
                        "threshold_percent": threshold,
                        "subject": f"Budget Alert – Account {acc_id} exceeded {threshold}%"
                    }
                    sns_client.publish(
                        TopicArn=sns_topic,
                        Subject=payload["subject"],
                        Message=json.dumps(payload)
                    )
                    logger.info(f"ALERT SENT for offending account {acc_id}")

                results.append({
                    "account_id": acc_id,
                    "budget_name": budget_name,
                    "percent_used": round(pct, 2),
                    "status": status
                })

        except Exception as e:
            for acc_id in accounts:
                results.append({
                    "account_id": acc_id,
                    "budget_name": budget_name,
                    "status": "ERROR",
                    "error": str(e)
                })

    return {"results": results}
EOT
        }
      }
    ]
  })
}



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

# }
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
resource "aws_iam_role" "budget_checker" {
  name = "OrganizationBudgetCheckerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ssm.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "allow_assume_member" {
  role = aws_iam_role.budget_checker.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::752338767189:role/budget_assume_role"
    }]
  })
}