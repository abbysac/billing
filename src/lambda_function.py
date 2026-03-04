# import boto3
# import json
# import logging
# import os
# import csv
# import re

# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# ses = boto3.client("ses")

# SENDER_EMAIL = "abbysac@gmail.com"
# AWS_REGION = "us-east-1"
# EMAIL_MAP_FILE = "/var/task/email_map.csv"


# def load_email_map():
#     mapping = {}
#     try:
#         with open(EMAIL_MAP_FILE, "r") as f:
#             reader = csv.DictReader(f)

#             for row in reader:
#                 linked = row.get("linked_account")
#                 email = row.get("email")

#                 if linked and email:
#                     mapping[linked.strip()] = email.strip()

#         logger.info("Loaded email map: %s", mapping)
#         return mapping

#     except Exception as e:
#         logger.error("Error reading email_map.csv: %s", e)
#         return {}


# def extract_budget_text_fields(message):
#     """
#     Extract fields from native AWS Budgets SNS text notification
#     """
#     account_match = re.search(r"AWS Account (\d+)", message)
#     budget_match = re.search(r"Budget Name: (.+)", message)
#     actual_match = re.search(r"ACTUAL Amount: \$([\d.]+)", message)
#     budgeted_match = re.search(r"Budgeted Amount: \$([\d.]+)", message)
#     threshold_match = re.search(r"Alert Threshold: > \$?([\d.]+)", message)

#     return {
#         "account_id": account_match.group(1) if account_match else None,
#         "budget_name": budget_match.group(1).strip() if budget_match else None,
#         "actual_spend_usd": actual_match.group(1) if actual_match else None,
#         "budget_limit_usd": budgeted_match.group(1) if budgeted_match else None,
#         "threshold": threshold_match.group(1) if threshold_match else None,
#     }


# def lambda_handler(event, context):
#     logger.info("Incoming SNS event: %s", json.dumps(event))

#     email_map = load_email_map()

#     for record in event.get("Records", []):
#         sns_msg = record.get("Sns", {}).get("Message", "")
#         logger.info("Raw SNS message: %s", sns_msg)

#         msg = None

#         # Try JSON first
#         try:
#             msg = json.loads(sns_msg)
#             logger.info("Parsed JSON message successfully")
#         except Exception:
#             logger.info("Message is not JSON, attempting text parse")

#         # If JSON parse failed, treat as AWS Budget native text
#         if not msg:
#             if "AWS Budget Notification" not in sns_msg:
#                 logger.warning("Message not recognized. Skipping.")
#                 continue

#             msg = extract_budget_text_fields(sns_msg)

#         # Validate required fields
#         required_keys = [
#             "account_id",
#             "budget_name",
#             "actual_spend_usd",
#             "budget_limit_usd"
#         ]

#         missing = [k for k in required_keys if not msg.get(k)]
#         if missing:
#             logger.error(f"Missing required fields: {missing}")
#             continue

#         acc_id = str(msg["account_id"])
#         budget = msg["budget_name"]
#         actual = msg["actual_spend_usd"]
#         limit = msg["budget_limit_usd"]
#         threshold = msg.get("threshold", "N/A")

#         recipient = email_map.get(acc_id)
#         if not recipient:
#             logger.error(f"No email mapping found for account {acc_id}")
#             continue

#         subject = f"Budget Alert - Account {acc_id}"

#         body = f"""
# Dear System Owner,

# This is to notify you that account {acc_id} has exceeded its AWS Budget threshold.

# Budget Name: {budget}

# Actual Spend:      ${actual}
# Budget Limit:      ${limit}
# Threshold Trigger: > ${threshold}

# Please review AWS Cost Explorer immediately.

# Thank you,
# OMF CloudOps
# """

#         try:
#             ses.send_email(
#                 Source=SENDER_EMAIL,
#                 Destination={"ToAddresses": [recipient]},
#                 Message={
#                     "Subject": {"Data": subject},
#                     "Body": {"Text": {"Data": body}}
#                 }
#             )
#             logger.info(f"SES email sent successfully to {recipient}")

#         except Exception as e:
#             logger.error(f"SES send error: {e}")
#             return {"statusCode": 500, "body": str(e)}

#     return {"statusCode": 200, "body": "SNS message processed"}


# import boto3
# import json
# import logging
# import os
# import csv
# import re

# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# # ses = boto3.client("ses")
# ses = boto3.client("ses", region_name="us-east-1")  # or your SES region

# SENDER_EMAIL = "abbysac@gmail.com"
# EMAIL_MAP_FILE = "/var/task/email_map.csv"


# # ----------------------------------------------------------
# # Load Account → Email Mapping From CSV
# # ----------------------------------------------------------
# def load_email_map():
#     mapping = {}
#     try:
#         with open(EMAIL_MAP_FILE, "r") as f:
#             reader = csv.DictReader(f)

#             for row in reader:
#                 linked = row.get("linked_account")
#                 email = row.get("email")

#                 if linked and email:
#                     mapping[linked.strip()] = email.strip()

#         logger.info("Loaded email map: %s", mapping)
#         return mapping

#     except Exception as e:
#         logger.error("Error reading email_map.csv: %s", e)
#         return {}


# # ----------------------------------------------------------
# # Extract Fields From Native AWS Budget Text Notification
# # ----------------------------------------------------------
# def extract_budget_text_fields(message):
#     """
#     Robust extraction of AWS Budget native text notification fields
#     """

#     # Normalize line endings
#     message = message.replace("\r", "")

#     # Extract account ID more safely (12-digit AWS account)
#     account_match = re.search(r"AWS\s+Account\s+(\d{12})", message, re.IGNORECASE)

#     if account_match:
#         account_id = account_match.group(1).strip()
#         logger.info("Extracted account ID: %s", account_id)
#     else:
#         logger.error("Failed to extract account ID from message")
#         account_id = None

#     # Extract other fields safely
#     budget_match = re.search(r"Budget Name:\s*(.+)", message)
#     actual_match = re.search(r"ACTUAL Amount:\s*\$?([\d.]+)", message)
#     budgeted_match = re.search(r"Budgeted Amount:\s*\$?([\d.]+)", message)
#     threshold_match = re.search(r"Alert Threshold:\s*>\s*\$?([\d.]+)", message)

#     return {
#         "account_id": account_id,
#         "budget_name": budget_match.group(1).strip() if budget_match else None,
#         "actual_spend_usd": actual_match.group(1) if actual_match else None,
#         "budget_limit_usd": budgeted_match.group(1) if budgeted_match else None,
#         "threshold": threshold_match.group(1) if threshold_match else None,
#     }


# # ----------------------------------------------------------
# # Lambda Handler
# # ----------------------------------------------------------
# def lambda_handler(event, context):

#     logger.info("Incoming SNS event: %s", json.dumps(event))
#     email_map = load_email_map()

#     for record in event.get("Records", []):
#         sns_msg = record.get("Sns", {}).get("Message", "")
#         logger.info("Raw SNS message: %s", sns_msg)

#         msg = None

#         # --------------------------------------------------
#         # Try JSON format first (custom structured format)
#         # --------------------------------------------------
#         try:
#             raw_json = json.loads(sns_msg)
#             logger.info("Parsed JSON message successfully")

#             msg = {
#                 "account_id": str(raw_json.get("offending_account_id")),
#                 "budget_name": raw_json.get("budget_name"),
#                 "actual_spend_usd": raw_json.get("actual_spend_usd"),
#                 "budget_limit_usd": raw_json.get("budget_limit_usd"),
#                 "threshold": raw_json.get("threshold_percent"),
#             }

#         except Exception:
#             logger.info("Message is not JSON. Attempting AWS Budget text parse.")

#             if "AWS Budget Notification" not in sns_msg:
#                 logger.warning("Message not recognized. Skipping.")
#                 continue

#             msg = extract_budget_text_fields(sns_msg)

#         # --------------------------------------------------
#         # Validate Required Fields
#         # --------------------------------------------------
#         required_keys = [
#             "account_id",
#             "budget_name",
#             "actual_spend_usd",
#             "budget_limit_usd",
#         ]

#         missing = [k for k in required_keys if not msg.get(k)]
#         if missing:
#             logger.error("Missing required fields: %s", missing)
#             continue

#         acc_id = str(msg["account_id"])
#         budget = msg["budget_name"]
#         actual = msg["actual_spend_usd"]
#         limit = msg["budget_limit_usd"]
#         threshold = msg.get("threshold", "N/A")

#         # --------------------------------------------------
#         # Lookup Email From CSV
#         # --------------------------------------------------
#         recipient = email_map.get(acc_id)

#         if not recipient:
#             logger.error("No email mapping found for account %s", acc_id)
#             continue

#         # --------------------------------------------------
#         # Build Email
#         # --------------------------------------------------
#         subject = f"Budget Alert - Account {acc_id}"

#         body = f"""
# Dear System Owner,

# AWS Budget threshold has been exceeded.

# Linked Account ID: {acc_id}
# Budget Name:       {budget}

# Actual Spend:      ${actual}
# Budget Limit:      ${limit}
# Threshold Trigger: {threshold}

# Please review AWS Cost Explorer immediately.

# Thank you,
# OMF CloudOps
# """

#         # --------------------------------------------------
#         # Send SES Email
#         # --------------------------------------------------
#         try:
#             ses.send_email(
#                 Source=SENDER_EMAIL,
#                 Destination={"ToAddresses": [recipient]},
#                 Message={
#                     "Subject": {"Data": subject},
#                     "Body": {"Text": {"Data": body}},
#                 },
#             )

#             logger.info("SES email sent successfully to %s", recipient)

#         except Exception as e:
#             logger.error("SES send error: %s", e)
#             return {"statusCode": 500, "body": str(e)}

#     return {"statusCode": 200, "body": "SNS message processed successfully"}

### Sends ses email with linked account id

# import boto3
# import json
# import logging
# import os
# import csv
# import re

# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# ses = boto3.client("ses", region_name=os.environ.get("AWS_REGION", "us-east-1"))
# sts = boto3.client("sts")
# org = boto3.client("organizations")

# SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "abbysac@gmail.com")
# EMAIL_MAP_FILE = os.environ.get("EMAIL_MAP_FILE", "/var/task/email_map.csv")

# FORCE_ALERT = os.environ.get("FORCE_ALERT", "false").lower() == "true"
# DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"


# # ----------------------------------------------------------
# # Get Management Account ID
# # ----------------------------------------------------------
# def extract_budget_name(message):
#     match = re.search(r'Budget Name\s*:\s*(.+)', message)
#     if match:
#         return match.group(1).strip()
#     return None

# def get_linked_account_from_budget(budget_name, payer_account_id):
#     budgets = boto3.client("budgets")

#     response = budgets.describe_budget(
#         AccountId=payer_account_id,
#         BudgetName=budget_name
#     )

#     budget = response["Budget"]
#     cost_filters = budget.get("CostFilters", {})

#     linked_accounts = cost_filters.get("LinkedAccount")

#     if linked_accounts:
#         return linked_accounts[0]

#     return payer_account_id  # fallback
# # ----------------------------------------------------------
# # Load CSV Email Mapping
# # ----------------------------------------------------------
# def load_email_map():
#     recipients = email_map.get("linked_account_id")
#     # SES requires list
#     recipients = [recipients]
#     mapping = {}
#     try:
#         with open(EMAIL_MAP_FILE, "r") as f:
#             reader = csv.DictReader(f)
#             for row in reader:
#                 mapping[row["linked_account"].strip()] = row["email"].strip()
#     except Exception as e:
#         logger.error("Email map load error: %s", e)
#     return mapping

# # # Load email mapping
# #     email_map = load_email_map()

# #     recipients = email_map.get("linked_account_id")

# #     if not recipients:
# #         logger.error(f"No email mapping found for account {"linked_account_id"}")
# #         return {"statusCode": 400}

# #     # SES requires list
# #     recipients = [recipients]
# # # ----------------------------------------------------------
# # Extract Account From Native Budget Text
# # ----------------------------------------------------------
# # def extract_account_from_text(message):
# #     match = re.search(r"\b(\d{12})\b", message)
# #     return match.group(1) if match else None


# # ----------------------------------------------------------
# # Lambda Handler
# # ----------------------------------------------------------
# def send_email(subject, body, recipients):

#         if not recipients:
#             logger.error("No recipients defined")
#             return

#         try:
#             ses = boto3.client("ses")

#             ses.send_email(
#                 Source=SENDER_EMAIL,
#                 Destination={
#                     "ToAddresses": recipients  # must be a LIST
#                 },
#                 Message={
#                     "Subject": {"Data": subject},
#                     "Body": {
#                         "Text": {"Data": body}
#                     }
#                 }
#             )

#             logger.info(f"Email sent to: {recipients}")

#         except Exception as e:
#             logger.error(f"SES error: {str(e)}")

# def lambda_handler(event, context):

#     record = event["Records"][0]
#     message = record["Sns"]["Message"]

#     # Get payer account ID from context
#     payer_account_id = context.invoked_function_arn.split(":")[4]

#     budget_name = extract_budget_name(message)

#     if not budget_name:
#         logger.error("Could not extract budget name")
#         return

#     linked_account_id = get_linked_account_from_budget(
#         budget_name,
#         payer_account_id
#     )

#     logger.info(f"Payer Account: {payer_account_id}")
#     logger.info(f"Linked Account: {linked_account_id}")

#     subject = f"Budget Alert - {payer_account_id} - {linked_account_id}"

#     body = f"""
# AWS Budget Alert {budget_name}

# Account Type:          {linked_account_id}
# Management Account ID: {payer_account_id}
# Reported Account ID:   {linked_account_id}

# If this is a payer-level budget, this alert reflects overall spend.

# Regards,
# OMF CloudOps
# """

#     try:
#             if DRY_RUN:
#                 logger.info("[DRY RUN] Would send to %s\n%s", EMAIL_MAP_FILE, body)
#             else:
#                 ses.send_email(
#                     Source=SENDER_EMAIL,
#                     Destination={"ToAddresses": recipients},
#                     Message={
#                         "Subject": {"Data": subject},
#                         "Body": {"Text": {"Data": body}},
#                     },
#                 )
#                 # logger.info(f"SES email sent successfully to {recipient}")
#                 logger.info("Email sent to %s", EMAIL_MAP_FILE)
#     except Exception as e:
#             logger.error("SES error: %s", e)

#     return {"statusCode": 200}

import boto3
import json
import logging
import os
import csv
import re

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
ses = boto3.client("ses", region_name=os.environ.get("AWS_REGION", "us-east-1"))
sts = boto3.client("sts")
budgets_client = boto3.client("budgets")

# Environment variables
SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "abbysac@gmail.com")
EMAIL_MAP_FILE = os.environ.get("EMAIL_MAP_FILE", "/var/task/email_map.csv")
FORCE_ALERT = os.environ.get("FORCE_ALERT", "false").lower() == "true"
DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"


# ----------------------------------------------------------
# Load CSV Email Mapping
# ----------------------------------------------------------
def load_email_map():
    mapping = {}
    try:
        with open(EMAIL_MAP_FILE, "r") as f:
            reader = csv.DictReader(f)
            for row in reader:
                linked_account = row.get("linked_account")
                email = row.get("email")
                if linked_account and email:
                    mapping[linked_account.strip()] = email.strip()
        logger.info("Loaded email map: %s", mapping)
    except Exception as e:
        logger.error("Error loading email map: %s", e)
    return mapping


# ----------------------------------------------------------
# Extract Budget Name from SNS Message
# ----------------------------------------------------------
def extract_budget_name(message):
    match = re.search(r"Budget Name\s*[:]*\s*(.+)", message)
    if match:
        return match.group(1).strip()
    return None


# ----------------------------------------------------------
# Get Linked Account ID from Budget Cost Filter
# ----------------------------------------------------------
def get_linked_account_from_budget(budget_name, payer_account_id):
    try:
        response = budgets_client.describe_budget(
            AccountId=payer_account_id,
            BudgetName=budget_name
        )
        budget = response["Budget"]
        cost_filters = budget.get("CostFilters", {})
        linked_accounts = cost_filters.get("LinkedAccount")
        if linked_accounts:
            return linked_accounts[0]
    except Exception as e:
        logger.error("Failed to fetch linked account from budget: %s", e)

    # fallback to payer if not found
    return payer_account_id


# ----------------------------------------------------------
# Send SES Email
# ----------------------------------------------------------
def send_email(subject, body, recipients):
    if not recipients:
        logger.error("No recipients defined")
        return

    # SES requires list
    if isinstance(recipients, str):
        recipients = [recipients]

    # Basic email validation
    valid_recipients = [r for r in recipients if "@" in r and "." in r.split("@")[-1]]
    if not valid_recipients:
        logger.error("No valid email recipients found: %s", recipients)
        return

    try:
        if DRY_RUN:
            logger.info("[DRY RUN] Would send to %s\n%s", valid_recipients, body)
        else:
            ses.send_email(
                Source=SENDER_EMAIL,
                Destination={"ToAddresses": valid_recipients},
                Message={
                    "Subject": {"Data": subject},
                    "Body": {"Text": {"Data": body}},
                },
            )
            logger.info("Email sent to %s", valid_recipients)
    except Exception as e:
        logger.error("SES error: %s", e)


# ----------------------------------------------------------
# Lambda Handler
# ----------------------------------------------------------
def lambda_handler(event, context):
    logger.info("Incoming SNS event: %s", json.dumps(event))

    email_map = load_email_map()

    # Get payer account from Lambda ARN
    payer_account_id = context.invoked_function_arn.split(":")[4]

    for record in event.get("Records", []):
        message = record.get("Sns", {}).get("Message", "")
        logger.info("Raw SNS message: %s", message)

        budget_name = extract_budget_name(message)
        if not budget_name:
            logger.error("Could not extract budget name from message")
            continue

        linked_account_id = get_linked_account_from_budget(budget_name, payer_account_id)
        logger.info(f"Payer Account: {payer_account_id}, Linked Account: {linked_account_id}")

        # Map linked account to recipient
        recipient = email_map.get(linked_account_id)
        if not recipient:
            logger.error(f"No email mapping found for linked account {linked_account_id}")
            continue

        subject = f"AWS Budget Alert - {budget_name}"
        body = f"""
Dear System Owner,

This is to notify you that the actual cost accrued yesterday in account number {linked_account_id} for {budget_name}
has exceeded percentage of the monthly limit budget.

Please verify your current utilization and cost trajectory.


Management Account ID: {payer_account_id}
Linked Account ID:     {linked_account_id}

Please review AWS Cost Explorer for details.

Regards,
OMF CloudOps
"""

        send_email(subject, body, recipient)

    return {"statusCode": 200, "body": "SNS message processed successfully"}