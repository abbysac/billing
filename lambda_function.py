import boto3
import decimal
import logging
import json

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# SES client
ses = boto3.client('ses', region_name='us-east-1')
ssm = boto3.client('ssm')

SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    logger.info(f"Received Event: {json.dumps(event, indent=2)}")

    # Try to extract SNS message
    sns_message = ""
    try:
        if isinstance(event, dict) and "Records" in event:
            sns_message = event["Records"][0].get("Sns", {}).get("Message", "")
        else:
            # Fallback for non-SNS events (e.g., SSM direct test)
            logger.info("No 'Records' key found, using raw event directly")
            sns_message = json.dumps(event) if isinstance(event, dict) else str(event)
    except Exception as e:
        logger.error(f"Error accessing SNS message: {e}")
        return {"statusCode": 400, "body": f"Unable to extract SNS message: {e}"}
    
    # if not sns_message.strip():
    #     logger.error("SNS message is empty or whitespace")
    #     return {"statusCode": 400, "body": "SNS message was empty"}

    # try:
    #     message = json.loads(sns_message)
    # except json.JSONDecodeError as e:
    #     logger.error(f"Failed to decode SNS message: {str(e)}")
    #     return {"statusCode": 400, "body": f"Invalid SNS message format: {str(e)}"}


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
        
#         #  Trigger SSM Automation if over threshold
#         if percentage_used >= threshold:
#             try:
#                 response = ssm.start_automation_execution(
#                 DocumentName='budget_update_gha_alert',
#                 Parameters={'TargetAccountId': [account_id]}
#  )
#                 print("SSM Automation triggered:", response)
#             except Exception as e:
#                 print(f"Failed to start SSM automation: {e}")
        
       
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