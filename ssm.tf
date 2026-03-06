# resource "aws_ssm_document" "check_budget_and_alert" {
#   name          = "budget_update_gha_alert"
#   document_type = "Automation"

#   content = jsonencode({
#     schemaVersion = "0.3"
#     description   = "Check AWS Budgets and invoke SES Lambda if threshold exceeded"

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
#         description = "Emails associated with budgets (not used in alerting)"
#         default     = [for item in local.csvfld : item.email]
#       }
#       ThresholdPercent = {
#         type        = "String"
#         description = "Budget threshold percentage to trigger alert"
#         default     = "80"
#       }
#       # LambdaFunctionName = {
#       #   type        = "String"
#       #   description = "Lambda function name to invoke for budget checking"
#       #   default     = "budget_update_gha_alert"
#       # }
#       BudgetsToCheck = {
#         type        = "String"
#         description = "JSON string of budgets to check"
#         default     = "[]"
#       }
#       TopicArn = {
#         type        = "String"
#         description = "SNS topic ARN (optional fallback)"
#         default     = "arn:aws:sns:us-east-1:224761220970:budget-updates-topic"
#         # default = "arn:aws:sns:us-east-1:224761220970:test-topic"
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
#           RoleSessionName = "BudgetCheck"
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
#             AccessKeyId     = "{{ AssumeManagementRole.AccessKeyId }}"
#             SecretAccessKey = "{{ AssumeManagementRole.SecretAccessKey }}"
#             SessionToken    = "{{ AssumeManagementRole.SessionToken }}"
#             MemberRoleName  = "{{ MemberRoleName }}"
#             SNSTopicArn     = "{{ TopicArn }}"

#             budgets_to_check = [
#               for k, v in local.accounts : {
#                 budget_name = v.budget_name
#                 threshold   = v.alert_threshold
#                 # sns_topic_arn   = v.sns_topic_arn
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


# def parse_event(event):
#     """
#     Normalize event to a Python dict.
#     Supports:
#       - native dict
#       - JSON string
#       - SNS-wrapped messages
#     """
#     logger.info("Raw event: %s", event)

#     # Case 1: SNS
#     if isinstance(event, dict) and "Records" in event:
#         try:
#             message = event["Records"][0]["Sns"]["Message"]
#             logger.info("SNS message detected")
#             return json.loads(message)
#         except Exception:
#             logger.exception("Failed to parse SNS message")
#             raise

#     # Case 2: JSON string
#     if isinstance(event, str):
#         logger.info("String payload detected")
#         return json.loads(event)

#     # Case 3: Already a dict
#     if isinstance(event, dict):
#         return event

#     raise ValueError(f"Unsupported event type: {type(event)}")


# def handler(event, context):
#     event = parse_event(event)
#     results = []

#     # Initialize Session
#     mgmt_creds = {
#         "aws_access_key_id": event["AccessKeyId"],
#         "aws_secret_access_key": event["SecretAccessKey"],
#         "aws_session_token": event["SessionToken"],
#     }
#     # FORCE REGION - SNS needs this to find the TopicArn
#     mgmt_session = boto3.Session(**mgmt_creds, region_name="us-east-1")
#     budgets_client = mgmt_session.client("budgets")
#     sns_client     = mgmt_session.client("sns")
#     sts_client     = mgmt_session.client("sts")

#     management_account_id = sts_client.get_caller_identity()["Account"]

#     # FETCH TOP-LEVEL TOPIC ARN
#     sns_topic = event.get("SNSTopicArn")

#     budgets_to_check = event.get("budgets_to_check", [])
#     for cfg in budgets_to_check:
#         budget_name = cfg["budget_name"]

#         # FORCE FLOAT CONVERSION HERE
#         threshold = float(cfg.get("threshold", 80)) 
#         accounts  = [str(a) for a in cfg.get("linked_accounts", [])]

#         try:
#             resp = budgets_client.describe_budget(
#                 AccountId=management_account_id,
#                 BudgetName=budget_name,
#             )

#             actual = float(resp["Budget"]["CalculatedSpend"]["ActualSpend"]["Amount"])
#             limit  = float(resp["Budget"]["BudgetLimit"]["Amount"])
#             pct    = (actual / limit * 100) if limit > 0 else 0

#             logger.info(f"Checking {budget_name}: {pct}% against {threshold}%")

#             for acc_id in accounts:
#                 status = "OK"

#                 # Comparison of two Floats
#                 if pct >= threshold:
#                     payload = {
#                         "offending_account_id": acc_id,
#                         "budget_name": budget_name,
#                         "actual_spend_usd": round(actual, 2),
#                         "budget_limit_usd": round(limit, 2),
#                         "percent_used": round(pct, 2),
#                         "threshold_percent": threshold,
#                         "subject": f"Budget Alert - Account {acc_id} exceeded {threshold}%",
#                     }

#                     # BOTO3 USES TopicArn (not SNSTopicArn)
#                     publish_resp = sns_client.publish(
#                         TopicArn=sns_topic,
#                         Subject=payload["subject"],
#                         Message=json.dumps(payload)
#                     )

#                     status = "ALERT_SENT"
#                     logger.info(f"PUBLISHED: {publish_resp.get('MessageId')}")

#                 results.append({
#                     "account_id": acc_id,
#                     "budget_name": budget_name,
#                     "percent_used": round(pct, 2),
#                     "status": status
#                 })

#         except Exception as e:
#             logger.exception(f"Error processing {budget_name}")
#             results.append({"budget_name": budget_name, "status": "ERROR", "error": str(e)})

#     return {"results": results}


# EOT
#         }
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
#     description   = "Check AWS Budgets across linked accounts and send SNS alerts"
#     assumeRole    = "{{ AutomationAssumeRole }}"

#     parameters = {
#       AutomationAssumeRole = {
#         type    = "String"
#         default = "arn:aws:iam::224761220970:role/AWS-SystemsManager-AutomationAdministrationRole"
#       }
#       BudgetsToCheck = {
#         type    = "String"
#         default = "[]"
#       }
#       Threshold = {
#         type    = "String"
#         default = "80"
#       }
#       SNSTopicArn = {
#         type    = "String"
#         default = "arn:aws:sns:us-east-1:224761220970:test-topic"
#       }
#       AccountRoleName = {
#         type    = "String"
#         default = "AWS-SystemsManager-AutomationAdministrationRole"
#       }
#     }

# mainSteps = [
#   {
#     name   = "CheckBudgetsMultiAccount"
#     action = "aws:executeScript"
#     inputs = {
#       Runtime = "python3.11"
#       Handler = "handler"
#       Script  = <<EOT
# import boto3
# import json
# import logging

# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# def assume_role(account_id, role_name):
#     sts = boto3.client("sts")
#     role_arn = f"arn:aws:iam::{account_id}:role/{role_name}"
#     resp = sts.assume_role(RoleArn=role_arn, RoleSessionName="BudgetCheckSession")
#     creds = resp["Credentials"]
#     return boto3.Session(
#         aws_access_key_id=creds["AccessKeyId"],
#         aws_secret_access_key=creds["SecretAccessKey"],
#         aws_session_token=creds["SessionToken"]
#     )

# def handler(event, context):
#     budgets_raw = event.get("BudgetsToCheck", "[]")
#     budgets = json.loads(budgets_raw) if isinstance(budgets_raw, str) else budgets
#     threshold = float(event.get("Threshold", 80))
#     sns_topic = event.get("SNSTopicArn")
#     role_name = event.get("AccountRoleName", "AWS-SystemsManager-AutomationAdministrationRole")

#     sns_client = boto3.client("sns")
#     results = []

#     for cfg in budgets:
#         budget_name = cfg.get("budget_name") or cfg.get("BudgetName")
#         linked_accounts = cfg.get("linked_accounts", [])
#         if not budget_name:
#             logger.warning("Budget entry missing name, skipping")
#             continue

#         # Always include the management account
#         accounts_to_check = [cfg.get("management_account_id")] if cfg.get("management_account_id") else []
#         accounts_to_check += linked_accounts

#         for account_id in accounts_to_check:
#             try:
#                 # Assume role in target account if not the current account
#                 if account_id != boto3.client("sts").get_caller_identity()["Account"]:
#                     session = assume_role(account_id, role_name)
#                     budgets_client = session.client("budgets")
#                 else:
#                     budgets_client = boto3.client("budgets")

#                 resp = budgets_client.describe_budget(
#                     AccountId=account_id,
#                     BudgetName=budget_name
#                 )

#                 actual = float(resp["Budget"]["CalculatedSpend"]["ActualSpend"]["Amount"])
#                 limit  = float(resp["Budget"]["BudgetLimit"]["Amount"])
#                 percent_used = (actual / limit * 100) if limit > 0 else 0.0

#                 logger.info(f"Budget '{budget_name}' in account {account_id}: {percent_used:.2f}% used")

#                 if percent_used >= threshold:
#                     message = {
#                         "account_id": account_id,
#                         "budget_name": budget_name,
#                         "percent_used": percent_used,
#                         "threshold": threshold
#                     }
#                     sns_client.publish(
#                         TopicArn=sns_topic,
#                         Subject=f"Budget Alert: {budget_name} (Account {account_id})",
#                         Message=json.dumps(message)
#                     )

#                 results.append({
#                     "account_id": account_id,
#                     "budget_name": budget_name,
#                     "percent_used": percent_used,
#                     "threshold_exceeded": percent_used >= threshold
#                 })

#             except Exception as e:
#                 logger.error(f"Error checking budget {budget_name} in account {account_id}: {str(e)}")
#                 results.append({
#                     "account_id": account_id,
#                     "budget_name": budget_name,
#                     "error": str(e)
#                 })

#     return {"results": results}
# EOT
#         }
#       }
#     ]
#   })
# }



####New
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
#         name   = "AssumeManagementRole"
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
# import json
# import logging
# import boto3

# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# ssm = boto3.client("ssm")

# def handler(event, context):

#     for record in event["Records"]:
#         message = record["Sns"]["Message"]

#         logger.info(f"Raw SNS message: {message}")

#         # Try JSON first
#         try:
#             payload = json.loads(message)
#             logger.info("Parsed JSON message")
#         except json.JSONDecodeError:
#             logger.info("Detected AWS Budgets native text format")

#             # Convert native text into structured payload
#             payload = {
#                 "budget_alert_text": message,
#                 "source": "aws_budgets_native"
#             }

#         # Trigger SSM regardless
#         response = ssm.start_automation_execution(
#             DocumentName="budget_update_gha_alert",
#             Parameters={
#                 "payload": [json.dumps(payload)]
#             }
#         )

#         logger.info(f"SSM triggered: {response['AutomationExecutionId']}")

#     return {"status": "SSM_TRIGGERED"}
# # import boto3
# # import json
# # import logging

# # logger = logging.getLogger()
# # logger.setLevel(logging.INFO)

# # def handler(events, context):
# #     results = []

# #     # Management account credentials — ALWAYS use these to read the budget
# #     mgmt_creds = {
# #         'aws_access_key_id': events['AccessKeyId'],
# #         'aws_secret_access_key': events['SecretAccessKey'],
# #         'aws_session_token': events['SessionToken']
# #     }

# #     # Always use management account session to read budget
# #     mgmt_session = boto3.Session(**mgmt_creds)
# #     budgets_client = mgmt_session.client('budgets')
# #     sns_client     = mgmt_session.client('sns')
# #     sts_client     = mgmt_session.client('sts')

# #     # Get management account ID
# #     management_account_id = sts_client.get_caller_identity()['Account']

# #     for cfg in events['budgets_to_check']:
# #         budget_name = cfg['budget_name']
# #         threshold   = float(cfg['threshold'])
# #         sns_topic   = cfg['sns_topic_arn']
# #         accounts    = [str(a) for a in cfg['linked_accounts']]

# #         try:
# #             # ALWAYS read the budget from the management account
# #             resp = budgets_client.describe_budget(
# #                 AccountId=management_account_id,
# #                 BudgetName=budget_name
# #             )
# #             actual = float(resp['Budget']['CalculatedSpend']['ActualSpend']['Amount'])
# #             limit  = float(resp['Budget']['BudgetLimit']['Amount'])
# #             pct    = (actual / limit * 100) if limit > 0 else 0

# #             for acc_id in accounts:
# #                 status = "OK"
# #                 if pct >= threshold:
# #                     status = "ALERT_SENT"
# #                     payload = {
# #                         "offending_account_id": acc_id,           # REAL linked account
# #                         "budget_name": budget_name,
# #                         "actual_spend_usd": round(actual, 2),
# #                         "budget_limit_usd": round(limit, 2),
# #                         "percent_used": round(pct, 2),
# #                         "threshold_percent": threshold,
# #                         "subject": f"Budget Alert – Account {acc_id} exceeded {threshold}%"
# #                     }
# #                     sns_client.publish(
# #                         TopicArn=sns_topic,
# #                         Subject=payload["subject"],
# #                         Message=json.dumps(payload)
# #                     )
# #                     logger.info(f"ALERT SENT for offending account {acc_id}")

# #                 results.append({
# #                     "account_id": acc_id,
# #                     "budget_name": budget_name,
# #                     "percent_used": round(pct, 2),
# #                     "status": status
# #                 })

# #         except Exception as e:
# #             for acc_id in accounts:
# #                 results.append({
# #                     "account_id": acc_id,
# #                     "budget_name": budget_name,
# #                     "status": "ERROR",
# #                     "error": str(e)
# #                 })

# #     return {"results": results}
# EOT
#         }
#       }
#     ]
#   })
# }


# resource "aws_ssm_document" "check_budget_and_alert" {
#   name          = "budget_update_gha_alert"
#   document_type = "Automation"
#   content = jsonencode({
#     schemaVersion = "0.3"
#     description   = "SSM Automation document to invoke Budget Alert Lambda for multiple accounts"

#     # Main steps of the automation
#     mainSteps = [
#       {
#         name   = "InvokeBudgetLambda"
#         action = "aws:invokeLambdaFunction" # REQUIRED
#         inputs = {
#           FunctionName = "budget_update_gha_alert" #required - name or ARN of the Lambda function to invoke
#           # Optionally pass a payload to Lambda
#           Payload = jsonencode({
#             dry_run     = true
#             force_alert = false
#           })
#         }
#       }
#     ]
#   })

#   # Optional: tags
#   tags = {
#     Environment = "prod"
#     ManagedBy   = "Terraform"
#   }
# }