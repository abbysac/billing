import json
import boto3
import decimal
import logging
import re
import traceback

ses = boto3.client('ses', region_name='us-east-1')  # Adjust to your SES region
ssm = boto3.client('ssm')
sns = boto3.client('sns')

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    logger.info("Received Event:\n" + json.dumps(event, indent=2, cls=DecimalEncoder))
    message = None

    try:
        if (
            "Records" in event
            and isinstance(event["Records"], list)
            and event["Records"]
            and "Sns" in event["Records"][0]
            and "Message" in event["Records"][0]["Sns"]
        ):
            sns_message = event["Records"][0]["Sns"]["Message"]
            logger.info(f"Raw SNS Message: {repr(sns_message)}")

            if not isinstance(sns_message, str) or not sns_message.strip():
                logger.error("SNS message is empty or not a string")
                return {"statusCode": 400, "body": "SNS message is empty or not a string"}

            try:
                message = json.loads(sns_message)
            except json.JSONDecodeError as e:
                logger.warning(f"Message is not JSON: {str(e)}. Falling back to regex-based parser.")
                account_id_match = re.search(r"AWS Account (\d+)", sns_message)
                budget_name_match = re.search(r"Budget Name: (.+)", sns_message)
                actual_spend_match = re.search(r"ACTUAL Amount: \$?([\d\.]+)", sns_message)
                budget_limit_match = re.search(r"Budgeted Amount: \$?([\d\.]+)", sns_message)
                alert_threshold_match = re.search(r"Alert Threshold: > \$?([\d\.]+)", sns_message)

                logger.info(f"Regex matches - account_id: {account_id_match}, budget_name: {budget_name_match}, actual_spend: {actual_spend_match}, budget_limit: {budget_limit_match}, alert_threshold: {alert_threshold_match}")

                if not all([account_id_match, budget_name_match, actual_spend_match, budget_limit_match]):
                    logger.error("Regex parsing failed for one or more fields")
                    return {"statusCode": 400, "body": "Failed to parse SNS message with regex"}

                message = {
                    "account_id": account_id_match.group(1),
                    "budgetName": budget_name_match.group(1).strip(),
                    "actual_spend": float(actual_spend_match.group(1)) if actual_spend_match else 0.0,
                    "budget_limit": float(budget_limit_match.group(1)) if budget_limit_match else 1.0,
                    "threshold_percent": float(alert_threshold_match.group(1)) if alert_threshold_match else 80.0,
                    "alert_trigger": "ACTUAL",
                    "environment": "stage"
                }
                if message["budget_limit"] > 0:
                    message["percentage_used"] = (message["actual_spend"] / message["budget_limit"]) * 100
                else:
                    message["percentage_used"] = 0.0
        elif "messages" in event and isinstance(event["messages"], list) and event["messages"]:
            logger.info("Processing AWS Budgets event")
            budget_event = event["messages"][0]
            message = {
                "account_id": budget_event.get("account_id", "Unknown"),
                "budgetName": budget_event.get("budgetName", "billing-alert"),
                "actual_spend": float(budget_event.get("CalculatedSpend", {}).get("ActualSpend", {}).get("Amount", 0.0)),
                "budget_limit": float(budget_event.get("BudgetLimit", {}).get("Amount", 1.0)),
                "environment": budget_event.get("environment", "prod"),
                "alert_trigger": "ACTUAL",
                "threshold_percent": 80.0
            }
            if message["budget_limit"] > 0:
                message["percentage_used"] = (message["actual_spend"] / message["budget_limit"]) * 100
            else:
                message["percentage_used"] = 0.0
        else:
            logger.error(f"Raw event missing required structure: {json.dumps(event, cls=DecimalEncoder)}")
            return {"statusCode": 400, "body": "Raw event missing required structure"}

    except Exception as e:
        logger.error(f"Error parsing event: {str(e)}\n{traceback.format_exc()}")
        return {"statusCode": 400, "body": f"Invalid event structure: {str(e)}"}

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
            error_msg = f"Missing required fields: {json.dumps(message, cls=DecimalEncoder)}"
            logger.error(error_msg)
            return {"statusCode": 400, "body": error_msg}

        logger.info(f"Threshold check: percentage_used={percentage_used:.2f}, threshold={threshold:.2f}")
        logger.info(f"{account_id} - {budget_name} used {percentage_used:.2f}% of budget, threshold: {threshold}%")

        if percentage_used < threshold:
            logger.info(f"{budget_name} usage ({percentage_used:.2f}%) below threshold ({threshold}%) - no email sent")
            return {"statusCode": 200, "body": "Threshold not exceeded"}

        subject = f"AWS Budget Alert: {budget_name}"
        try:
            email_body = f"""
{account_id} {budget_name}
Dear System Owner,

This is to notify you that the actual cost accrued yesterday in "{environment}" for "{budget_name}" has exceeded
{percentage_used:.1f}% of ${budget_limit:.2f} monthly value of budget. Please verify your
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
        except TypeError as e:
            logger.error(f"Failed to serialize message to JSON: {str(e)}")
            email_body = f"""
{account_id} {budget_name}
Dear System Owner,

This is to notify you that the actual cost accrued yesterday in "{environment}" for "{budget_name}" has exceeded
{percentage_used:.1f}% of ${budget_limit:.2f} monthly value of budget. Please verify your
current utilization and cost trajectory. If necessary, please update your annual budget in omfmgmt.

Thank you,
OMF CloudOps

Budget Name: {budget_name}
Account ID: {account_id}
Environment: {environment}
Budget Limit: ${budget_limit:.2f}
Actual Spend: ${actual_spend:.2f}

Full Message: Unable to serialize message
"""

        try:
            response = ses.send_email(
                Source=SENDER_EMAIL,
                Destination={'ToAddresses': [RECIPIENT_EMAIL]},
                Message={
                    'Subject': {'Data': subject, 'Charset': 'UTF-8'},
                    'Body': {
                        'Text': {
                            'Data': email_body,
                            'Charset': 'UTF-8'
                        }
                    }
                }
            )
            logger.info(f"Email sent! Message ID: {response['MessageId']}")
        except ses.exceptions.ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            logger.error(f"SES ClientError: {error_code} - {error_message}")
            return {"statusCode": 500, "body": f"Failed to send email: {error_code} - {error_message}"}
        except Exception as e:
            logger.error(f"Unexpected error sending email: {str(e)}\n{traceback.format_exc()}")
            return {"statusCode": 500, "body": f"Failed to send email: {str(e)}"}

        return {"statusCode": 200, "body": "Email sent successfully"}

    except Exception as e:
        logger.error(f"Error in main handler logic: {str(e)}\n{traceback.format_exc()}")
        return {"statusCode": 400, "body": f"Unexpected processing error: {str(e)}"}