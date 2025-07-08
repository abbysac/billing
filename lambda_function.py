import boto3
import decimal
import logging
import json

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# SES client
ses = boto3.client('ses', region_name='us-east-1')

SENDER_EMAIL = "abbysac@gmail.com"  # SES-verified email
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    logger.info(f"Received Event: {json.dumps(event, indent=2)}")

    # Extract message
    try:
        if "Records" in event and isinstance(event["Records"], list) and len(event["Records"]) > 0:
            sns_message = event["Records"][0]["Sns"]["Message"]
            if not sns_message:
                logger.error("SNS message is empty")
                return {"statusCode": 400, "body": "Empty SNS message"}
            message = json.loads(sns_message) if isinstance(sns_message, str) else sns_message
            logger.info(f"Parsed SNS Message: {json.dumps(message, indent=2)}")
        else:
            logger.info("Direct event received (e.g., from SSM), using raw event.")
            message = event
    except (KeyError, IndexError, json.JSONDecodeError) as e:
        logger.error(f"Error parsing event: {str(e)}")
        return {"statusCode": 400, "body": f"Invalid event format: {str(e)}"}

    # Extract budget details
    try:
        account_id = message.get("account_id", message.get("TargetAccountId", "Unknown"))
        budget_name = message.get("budgetName", message.get("BudgetName", "billing-alert"))
        actual_spend = float(message.get("actual_spend", message.get("ActualSpend", message.get("actualAmount", 0.0))))
        budget_limit = float(message.get("budget_limit", message.get("BudgetLimit", message.get("budgetLimit", 1.0))))
        percentage_used = float(message.get("percentage_used", (actual_spend / budget_limit * 100 if budget_limit else 0)))
        alert_trigger = message.get("alert_trigger", message.get("AlertTrigger", message.get("alertType", "ACTUAL")))
        environment = message.get("environment", "stage")
        threshold = float(message.get("threshold_percent", message.get("AlertThreshold", 80.0)))

        if not all([account_id, budget_name]):
            error_msg = f"Missing required fields: {message}"
            logger.error(error_msg)
            return {"statusCode": 400, "body": error_msg}

        logger.info(f"{account_id} - {budget_name} used {percentage_used:.2f}% of budget, threshold: {threshold}%")

        if percentage_used < threshold:
            logger.info(f"{budget_name} usage ({percentage_used:.2f}%) below threshold ({threshold}%) - no email sent")
            return {"statusCode": 200, "body": "Threshold not exceeded"}

        # Send email
        subject = f"AWS Budget Alert: {budget_name}"
        email_body = f"""
{account_id} {budget_name}
Dear System Owner,

The actual cost accrued in "{environment}" for "{budget_name}" has exceeded
{percentage_used:.1f}% of the monthly budget of ${budget_limit:.2f}.
Current actual spend: ${actual_spend:.2f}.

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
                'Body': {
                    'Text': {
                        'Data': email_body,
                        'Charset': 'UTF-8'
                    }
                }
            }
        )
        logger.info(f"Email sent! Message ID: {response['MessageId']}")
        return {"statusCode": 200, "body": "Email sent successfully"}

    except Exception as e:
        logger.error(f"Error in main handler logic: {str(e)}")
        return {"statusCode": 500, "body": f"Unexpected processing error: {str(e)}"} 


