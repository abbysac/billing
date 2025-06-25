import json
import boto3
import decimal
import logging
import time
from botocore.exceptions import ClientError

ses = boto3.client('ses', region_name='us-east-1')

SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)
    

    


def lambda_handler(event, context):
    if "Records" in event and isinstance(event["Records"], list):
        try:
            sns_message = event["Records"][0]["Sns"]["Message"]
            print(f"Raw SNS Message: {sns_message}")  # <--- Add this
            message = json.loads(sns_message)
        except (KeyError, IndexError, json.JSONDecodeError) as e:
            print(f"Error parsing SNS message: {str(e)}")
            return {"statusCode": 400, "body": "Invalid SNS event format"}


    # print("Received Event:", json.dumps(event, indent=2))

    # try:
    #     sns_record = event['Records'][0]['Sns']
    #     sns_message_str = sns_record['Message']
    #     message = json.loads(sns_message_str)
    #     logging.info(f"Processed SNS Message: {message}")
    # except Exception as e:
    #     print(f"Failed to parse SNS message: {e}")
    #     return {"statusCode": 400, "body": "Invalid SNS message format"}

    try:
        account_id = message.get("account_id")
        budget_name = message.get("budgetName")
        actual_spend = float(message.get("actual_spend", 0.0))
        budget_limit = float(message.get("budget_limit", 1.0))
        percentage_used = float(message.get("percentage_used", 0.0))
        alert_trigger = message.get("alert_trigger", "ACTUAL")
        environment = message.get("environment", "stage")
        threshold = float(message.get("threshold_percent", 80.0))

        if not all([account_id, budget_name, actual_spend is not None, budget_limit is not None, percentage_used is not None]):
            error_msg = f"Missing required fields: {message}"
            print(error_msg)
            return {"statusCode": 400, "body": error_msg}

        print(f"[INFO] {account_id} - {budget_name} used {percentage_used:.2f}% of budget, threshold: {threshold}%")

        if percentage_used < threshold:
            print(f"[INFO] {budget_name} usage ({percentage_used:.2f}%) below threshold ({threshold}%) - no email sent")
            return {"statusCode": 200, "body": "Threshold not exceeded"}

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
            return {"statusCode": 200, "body": "Email sent successfully"}
        except Exception as e:
            print(f"Failed to send email: {str(e)}")
            return {"statusCode": 500, "body": f"Failed to send email: {str(e)}"}

    except Exception as e:
        print(f"Error in main handler logic: {e}")
        return {"statusCode": 400, "body": "Unexpected processing error"}           