import boto3
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ses = boto3.client("ses")

# You may store these in Lambda environment variables:
DEFAULT_RECIPIENT = os.environ.get("ALERT_EMAIL", "camleous@yahoo.com")
DEFAULT_SENDER    = os.environ.get("SES_FROM_EMAIL", "abbysac@gmail.com")

def lambda_handler(event, context):
    logger.info("Incoming SNS event: %s", json.dumps(event))

    for record in event.get("Records", []):
        sns_msg = record.get("Sns", {}).get("Message", "")
        logger.info("Raw SNS message: %s", sns_msg)

        # -----------------------------------------------------
        # TRY PARSING SNS MESSAGE AS JSON
        # -----------------------------------------------------
        try:
            msg = json.loads(sns_msg)
            is_json = True
        except Exception:
            is_json = False

        # -----------------------------------------------------
        # IGNORE AWS BUDGET NATIVE TEXT NOTIFICATIONS
        # -----------------------------------------------------
        if not is_json:
            logger.warning("Ignoring AWS Budgets native text notification")
            continue

        # -----------------------------------------------------
        # PROCESS JSON MESSAGE (FROM SSM AUTOMATION)
        # -----------------------------------------------------
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

        offending = msg["offending_account_id"]
        budget    = msg["budget_name"]
        actual    = msg["actual_spend_usd"]
        limit     = msg["budget_limit_usd"]
        pct_used  = msg["percent_used"]
        threshold = msg["threshold_percent"]

        subject = msg.get(
            "subject",
            f"Budget Alert - Account {offending}"
        )

        body = f"""

Dear System Owner,

This is to notify you that the actual cost accrued yesterday in {offending} for {budget} has exceeded
{pct_used}% of {limit} monthly value of budget. Please verify your
current utilization and cost trajectory. If necessary, please update your annual budget in omfmgmt.

Thank you,
OMF CloudOps

Offending Account: {offending}
Budget Name:       {budget}

Actual Spend:      ${actual}
Budget Limit:      ${limit}
Percent Used:      {pct_used}%
Threshold:         {threshold}%

AWS Budget threshold has been exceeded.
"""

        # -----------------------------------------------------
        # SEND SES EMAIL
        # -----------------------------------------------------
        try:
            ses.send_email(
                Source=DEFAULT_SENDER,
                Destination={"ToAddresses": [DEFAULT_RECIPIENT]},
                Message={
                    "Subject": {"Data": subject},
                    "Body": {"Text": {"Data": body}}
                }
            )
            logger.info("SES email sent successfully for account %s", offending)

        except Exception as e:
            logger.error("SES email error: %s", e)
            return {"statusCode": 500, "body": str(e)}

    return {"statusCode": 200, "body": "SNS message processed"}
