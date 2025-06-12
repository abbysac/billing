import json
import boto3
import decimal
import logging

ses = boto3.client('ses')
ssm = boto3.client('ssm')

SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    print("Received Event:", json.dumps(event, indent=2))

    message =json.loads(event['Records'][0]['Sns']['Message'])
    logging.info(f"Processed SNS Message: {message}")

    try:
        # Extract SNS payload
        sns_record = event['Records'][0]['Sns']
        sns_message_str = sns_record['Message']
        message = json.loads(sns_message_str)
    except Exception as e:
        print(f"Failed to parse SNS message: {e}")
        return {
            "statusCode": 400,
            "body": "Invalid SNS message format"
        }

    try:
        # Extract values
        account_id = message.get("account_id")
        budget_name = message.get("budgetName")
        threshold = float(message.get("threshold", 80.0))
        actual_spend = float(message.get("amount", 0.0))
        budget_limit = float(message.get("budgetLimit", 1.0))
        environment = message.get("environment", "stage")

        percent_used = (actual_spend / budget_limit) * 100 if budget_limit > 0 else 0

        print(f"[INFO] {account_id} - {budget_name} used {percent_used:.2f}% of budget")

        # # 🔁 Trigger SSM Automation if over threshold
        # if percent_used >= threshold:
        #     try:
        #         response = ssm.start_automation_execution(
        #             DocumentName='budget_update_gha_alert',
        #             Parameters={'TargetAccountId': [account_id]}
        #         )
        #         print("SSM Automation triggered:", response)
        #     except Exception as e:
        #         print(f"Failed to start SSM automation: {e}")

        subject = f"AWS Budget Alert: {budget_name}"
        email_body = f"""
{account_id} {budget_name}
Dear System Owner,

The actual cost accrued yesterday in "{environment}" for "{budget_name}" has exceeded
{percent_used:.1f}% of the monthly budget of ${budget_limit:.2f}.
Current actual spend: ${actual_spend:.2f}.

Thank you,  
OMF CloudOps

Budget Name: {budget_name}
Account ID: {account_id}
Environment: {environment}
Budget Limit: ${budget_limit:.2f}

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
