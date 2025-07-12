import json
import boto3
import decimal
import logging
# import bootcore.exceptions
import re

ses = boto3.client('ses')
ssm = boto3.client('ssm')
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()
sns = boto3.client('sns')

SENDER_EMAIL = "abbysac@gmail.com"   #SES verified email
RECIPIENT_EMAIL = "camleous@yahoo.com"  #recipient email

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
           return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    logger.info("Received Event:\n" + json.dumps(event, indent=2))
    message = None  # ✅ ensure variable is always defined

    try:
        if (
            "Records" in event
            and isinstance(event["Records"], list)
            and event["Records"]
            and "Sns" in event["Records"][0]
        ):
            sns_message = event["Records"][0]["Sns"].get("Message", "")
            logger.info(f"Raw SNS Message: {repr(sns_message)}")

            if not isinstance(sns_message, str) or not sns_message.strip():
                logger.error("SNS message is empty or blank.")
                return {"statusCode": 400, "body": "SNS message is empty or blank."}

            # Try parsing JSON
            try:
                message = json.loads(sns_message)
            except json.JSONDecodeError:
                logger.warning("Message is not JSON. Falling back to regex-based parser.")
                # Fallback: extract from plain-text message
                import re
                account_id = re.search(r"AWS Account (\d+)", sns_message)
                budget_name = re.search(r"Budget Name: (.+)", sns_message)
                actual_spend = re.search(r"ACTUAL Amount: \$?([\d\.]+)", sns_message)
                budget_limit = re.search(r"Budgeted Amount: \$?([\d\.]+)", sns_message)
                alert_threshold = re.search(r"Alert Threshold: > \$?([\d\.]+)", sns_message)

                message = {
                    "account_id": account_id.group(1) if account_id else "Unknown",
                    "budgetName": budget_name.group(1).strip() if budget_name else "Unknown",
                    "actual_spend": float(actual_spend.group(1)) if actual_spend else 0.0,
                    "budget_limit": float(budget_limit.group(1)) if budget_limit else 1.0,
                    "threshold_percent": 80.0,
                    "alert_trigger": "ACTUAL",
                    "environment": "prod"
                }

                # Compute percentage used
                if message["budget_limit"] > 0:
                    message["percentage_used"] = (message["actual_spend"] / message["budget_limit"]) * 100
                else:
                    message["percentage_used"] = 0.0

        else:
            logger.warning("No SNS Records found. Using raw event directly.")
            message = event

    except Exception as e:
        logger.error(f"Error parsing SNS message: {e}")
        return {"statusCode": 400, "body": "Invalid SNS event structure"}

    #✅ message is now always defined — safe to proceed
    #... (rest of your code)

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
        # if percentage_used >= threshold:
        #     try:
        #         response = ssm.start_automation_execution(
        #         DocumentName='budget_update_gha_alert',
        #         Parameters={'TargetAccountId': [account_id]}
        # )
        #         print("SSM Automation triggered:", response)
        #     except Exception as e:
        #         print(f"Failed to start SSM automation: {e}")

        subject = f"AWS Budget Alert: {budget_name}"
        email_body = f"""
{account_id} {budget_name}
Dear System Owner,
    This is to notify you that the actual cost accrued yesterday in "{environment}" for "{budget_name}" has exceeded
    {percentage_used:.1f}% of  ${budget_limit:.2f}.  monthly value of budget. Please verify your 
    current utilization and cost trajectory. If necessary, please update your annual budget in omfmgmt.

    Thank you, 
    OMF CloudOps

    Budget Name: {budget_name}
    Account ID: {account_id}
    Environment: {environment}
    Budget Limit: ${budget_limit:.2f}
    Actual Spend: ${actual_spend:.2f}

    Full Message:
    {json.dumps(message, indent=2, cls=DecimalEncoder)}
    """

        try:
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
            print(f"Email sent! Message ID: {response['MessageId']}")
        except Exception as e:
            print(f"Failed to send email: {str(e)}")
            return {"statusCode": 500, "body": "Failed to send email"}

        return {"statusCode": 200, "body": "Email sent successfully"}
    except Exception as e:
        print(f"Error in main handler logic: {e}")
        return {"statusCode": 400, "body": "Unexpected processing error"}