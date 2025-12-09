import boto3
import json
import logging
import os
import csv

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ses = boto3.client("ses")

SENDER_EMAIL = "abbysac@gmail.com"
AWS_REGION = "us-east-1"
EMAIL_MAP_FILE = "/var/task/email_map.csv"

def load_email_map():
    mapping = {}
    try:
        with open(EMAIL_MAP_FILE, "r") as f:
            reader = csv.DictReader(f)

            for row in reader:
                linked = row.get("linked_account")
                email  = row.get("email")

                if linked and email:
                    mapping[linked.strip()] = email.strip()

        logger.info("Loaded email map: %s", mapping)
        return mapping

    except Exception as e:
        logger.error("Error reading email_map.csv: %s", e)
        return {}

def lambda_handler(event, context):
    logger.info("Incoming SNS event: %s", json.dumps(event))

    email_map = load_email_map()

    for record in event.get("Records", []):
        sns_msg = record.get("Sns", {}).get("Message", "")
        logger.info("Raw SNS message: %s", sns_msg)

        # Try to parse JSON (SSM events)
        try:
            msg = json.loads(sns_msg)
        except Exception:
            logger.warning("Ignoring AWS Budgets native text notification")
            continue

        required_keys = [
            "offending_account_id",
            "budget_name",
            "actual_spend_usd",
            "budget_limit_usd",
            "percent_used",
            "threshold_percent"
        ]

        missing = [k for k in required_keys if k not in msg]
        if missing:
            error = f"Missing required JSON fields: {', '.join(missing)}"
            logger.error(error)
            return {"statusCode": 400, "body": error}

        acc_id = str(msg["offending_account_id"])
        budget = msg["budget_name"]
        actual = msg["actual_spend_usd"]
        limit  = msg["budget_limit_usd"]
        pct    = msg["percent_used"]
        threshold = msg["threshold_percent"]

        recipient = email_map.get(acc_id)
        if not recipient:
            logger.error(f"No email mapping found for account {acc_id}")
            continue

        subject = f"Budget Alert - Account {acc_id}"

        body = f"""
Dear System Owner,

This is to notify you that the actual cost accrued yesterday in account number {acc_id} for {budget}
has exceeded {pct}% of the ${limit} monthly budget.

Please verify your current utilization and cost trajectory.

Thank you,
OMF CloudOps

Offending Account: {acc_id}
Budget Name:       {budget}

Actual Spend:      ${actual}
Budget Limit:      ${limit}
Percent Used:      {pct}%
Threshold:         {threshold}%

AWS Budget threshold has been exceeded.
"""

        try:
            ses.send_email(
                Source=SENDER_EMAIL,
                Destination={"ToAddresses": [recipient]},
                Message={
                    "Subject": {"Data": subject},
                    "Body": {"Text": {"Data": body}}
                }
            )
            logger.info(f"SES email sent successfully to {recipient}")

        except Exception as e:
            logger.error(f"SES send error: {e}")
            return {"statusCode": 500, "body": str(e)}

    return {"statusCode": 200, "body": "SNS message processed"}
