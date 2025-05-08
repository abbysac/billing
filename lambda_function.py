import json
import boto3
import os

ses = boto3.client('ses', region_name="us-east-1")

SENDER_EMAIL = "abbysac@gmail.com"  # SES-verified email
RECIPIENT_EMAIL = "camleous@yahoo.com"

# SENDER_EMAIL = os.environ['SENDER_EMAIL']
# RECIPIENT_EMAILS = os.environ['RECIPIENT_EMAILS'].split(',')


def lambda_handler(event, context):
    print("Received Event:", json.dumps(event, indent=2))

    # Extract SNS message
    if "Records" in event and isinstance(event["Records"], list):
        try:
            parsed_message = json.loads(sns_message)
        except json.JSONDecodeError:
            parsed_message = sns_message
        # try:
        #     sns_message = event["Records"][0]["Sns"]["Message"]
        #     message = json.loads(sns_message)
        # except (KeyError, IndexError, json.JSONDecodeError) as e:
        #     print(f"Error parsing SNS message: {str(e)}")
        #     return {"statusCode": 400, "body": "Invalid SNS event format"}
    else:
        print("Direct Budget event received, using raw event.")
        message = event

    # Extract budget details
    budget_name = message.get("budgetName", "billing-alert")
    alert_type = message.get("alertType", "ACTUAL")
    amount = message.get("amount", "2.00")

    subject = f"AWS Budget Alert: {budget_name}"
    body = f"""224761220970 , dev
Dear System Owner,

This is to notify you that the actual cost accrued yesterday in “svcshubdev” has exceeded
80% the amount of $1 daily value, based on a $4.00 monthly budget. Please verify your 
current utilization and cost trajectory. If necessary, please update your annual budget in omfmgmt.

Thank you,
OMF CloudOps.

Budget Name: {budget_name}
Alert Type: {alert_type}
Amount: ${amount}

Full Message:
{json.dumps(message, indent=2)}
"""

    # Send plain text email (no HTML, no templates)
    response = ses.send_email(
        Source=SENDER_EMAIL,
        Destination={'ToAddresses': [RECIPIENT_EMAIL]},
        Message={
            'Subject': {'Data': subject},
            'Body': {
                'Text': {
                    'Data': body,
                    'Charset': 'UTF-8'
                }
            }
        }
    )

    print(f"Email sent! Message ID: {response['MessageId']}")
    return {"statusCode": 200, "body": "Email sent successfully"}
