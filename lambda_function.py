import json
import boto3
import decimal

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

    # Extract and parse SNS message
    try:
        sns_message = event["Records"][0]["Sns"]["Message"]
        print(f"Raw SNS Message: '{sns_message}'")

        if not isinstance(sns_message, str) or not sns_message.strip():
            print("Error: SNS message is empty")
            return {"statusCode": 400, "body": "SNS message body is empty"}

        message = json.loads(sns_message)
    except Exception as e:
        print(f"Error parsing SNS message: {str(e)}")
        return {"statusCode": 400, "body": f"Invalid SNS format: {str(e)}"}

    try:
        account_id = message.get("account_id")
        budget_name = message.get("budgetName")
        threshold = float(message.get("threshold", 80.0))
        actual_spend = float(message.get("actual_spend"))
        budget_limit = float(message.get("budgetLimit"))
        environment = message.get("environment", "stage")

        percent_used = (actual_spend / budget_limit) * 100 if budget_limit > 0 else 0
        print(f"[INFO] {account_id} - {budget_name} used {percent_used:.2f}% of budget")

        subject = f"AWS Budget Alert: {budget_name}"
        email_body = f"""
{account_id} - {budget_name}
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
        print(f"Error in handler: {str(e)}")
        return {"statusCode": 500, "body": f"Internal error: {str(e)}"}

