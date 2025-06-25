import json
import boto3
import decimal
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# SES client
ses = boto3.client('ses', region_name='us-east-1')

# Update with verified SES email addresses
SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def parse_event(event):
    """
    Handles both SNS-triggered events and direct test payloads.
    Returns a single budget message dict or None.
    """
    try:
        # SNS-based event
        if "Records" in event and isinstance(event["Records"], list):
            for record in event["Records"]:
                sns_message = record.get("Sns", {}).get("Message", "")
                logger.info(f"Raw SNS message: {sns_message}")
                if sns_message.strip():
                    return json.loads(sns_message)
                else:
                    logger.error("SNS message is empty or whitespace")
                    return None
        # Direct test payload
        elif "account_id" in event or "accountId" in event:
            logger.info("Direct budget object received.")
            return event
        # Invalid format (e.g. {"messages": [...]})
        elif "messages" in event:
            logger.warning("Only one message expected. Using first from 'messages' array.")
            return event["messages"][0]
        else:
            logger.error("Unrecognized event format")
            return None
    except Exception as e:
        logger.error(f"Failed to parse event: {str(e)}")
        return None

def lambda_handler(event, context):
    logger.info(f"Received Event: {json.dumps(event, indent=2)}")

    message = parse_event(event)
    if not message:
        return {"statusCode": 400, "body": "Invalid or empty message"}

    try:
        account_id = message.get("account_id") or message.get("accountId")
        budget_name = message.get("budgetName") or message.get("BudgetName", "billing-alert")
        actual_spend = float(
            message.get("actual_spend") or
            message.get("ActualSpend") or
            message.get("CalculatedSpend", {}).get("ActualSpend", {}).get("Amount", 0.0)
        )
        budget_limit = float(
            message.get("budget_limit") or
            message.get("BudgetLimit") or
            message.get("BudgetLimit", {}).get("Amount", 1.0)
        )
        percentage_used = float(
            message.get("percentage_used") or
            (actual_spend / budget_limit * 100 if budget_limit else 0)
        )
        threshold = float(message.get("threshold_percent") or message.get("AlertThreshold", 80.0))
        alert_trigger = message.get("alert_trigger") or message.get("AlertTrigger") or "ACTUAL"
        environment = message.get("environment", "stage")

        # Validate required fields
        if not account_id or not budget_name:
            error_msg = f"Missing required fields: {json.dumps(message)}"
            logger.error(error_msg)
            return {"statusCode": 400, "body": error_msg}

        logger.info(f"{account_id} - {budget_name} used {percentage_used:.2f}% of budget (threshold: {threshold}%)")

        if percentage_used < threshold:
            logger.info(f"{budget_name}: usage {percentage_used:.2f}% is below threshold {threshold}%. No email sent.")
            return {"statusCode": 200, "body": "Threshold not exceeded"}

        # Compose and send SES email
        subject = f"AWS Budget Alert: {budget_name}"
        email_body = f"""
{account_id} - {environment} Budget Alert

Dear System Owner,

The actual cost in "{environment}" for "{budget_name}" has exceeded
{percentage_used:.1f}% of the monthly budget of ${budget_limit:.2f}.
Current actual spend: ${actual_spend:.2f}.

Please review usage and adjust the budget if necessary.

Thank you,  
OMF CloudOps

Budget Name: {budget_name}
Account ID: {account_id}
Environment: {environment}
Budget Limit: ${budget_limit:.2f}
Alert Trigger: {alert_trigger}

Full Message:
{json.dumps(message, indent=2, cls=DecimalEncoder)}
"""

        response = ses.send_email(
            Source=SENDER_EMAIL,
            Destination={'ToAddresses': [RECIPIENT_EMAIL]},
            Message={
                'Subject': {'Data': subject},
                'Body': {'Text': {'Data': email_body, 'Charset': 'UTF-8'}}
            }
        )
        logger.info(f"Email sent! SES Message ID: {response['MessageId']}")
        return {"statusCode": 200, "body": "Email sent successfully"}

    except Exception as e:
        logger.error(f"Error in main handler logic: {str(e)}")
        return {"statusCode": 500, "body": f"Unexpected processing error: {str(e)}"}
