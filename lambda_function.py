import json
import boto3
import os

ses = boto3.client('ses', region_name="us-east-1")

# Environment variables for sender and recipient
SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "abbysac@gmail.com")      # SES-verified sender
RECIPIENT_EMAIL = os.environ.get("RECIPIENT_EMAIL", "camleous@yahoo.com")  # Can be comma-separated for multiple

def lambda_handler(event, context):
    print("Received Event:", json.dumps(event, indent=2))

    message = {}

    # Extract SNS message if triggered by SNS
    if "Records" in event and isinstance(event["Records"], list):
        try:
            sns_message = event["Records"][0]["Sns"]["Message"]
            try:
                message = json.loads(sns_message)
            except json.JSONDecodeError:
                print("SNS message is plain text, not JSON.")
                message = {"rawMessage": sns_message}
        except (KeyError, IndexError) as e:
            print(f"Error extracting SNS message: {str(e)}")
            return {"statusCode": 400, "body": "Invalid SNS event format"}
    else:
        print("Direct Budget event received, using raw event.")
        message = event

    # Extract metadata
    budget_name = message.get("budgetName", "billing-alert")
    alert_type = message.get("alertType", "ACTUAL")
    account_id = message.get("accountId", "224761220970","752338767189")
    environment = message.get("environment", "dev","stage","prod")

    # Extract actual spend and budget limit dynamically
    try:
        actual_spend = float(message.get("CalculatedSpend", {}).get("ActualSpend", {}).get("Amount", 0.0))
        budget_limit = float(message.get("BudgetLimit", {}).get("Amount", 1.0))  # fallback to avoid ZeroDivisionError
        percentage_used = (actual_spend / budget_limit) * 100 if budget_limit else 0
        amount = f"{actual_spend:.2f}"
    except Exception as e:
        print("Error calculating amount from message:", str(e))
        actual_spend = 0.0
        budget_limit = 1.0
        percentage_used = 0
        amount = message.get("amount", "2.00")

    subject = f"AWS Budget Alert: {budget_name} (Account: {account_id})"

    body = f"""{account_id}, {environment}

Dear System Owner,

This is to notify you that the actual cost accrued yesterday in “{environment}” has exceeded
{int(percentage_used)}% of the monthly budget of ${budget_limit:.2f}.
Current actual spend: ${amount}

Please verify your current utilization and cost trajectory. If necessary, update your budget in OMFMgmt.

Thank you,
OMF CloudOps

Budget Name: {budget_name}
Alert Type: {alert_type}

Full Message:
{json.dumps(message, indent=2)}
"""

    # Send email
    try:
        response = ses.send_email(
            Source=SENDER_EMAIL,
            Destination={'ToAddresses': [e.strip() for e in RECIPIENT_EMAIL.split(",")]},
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
        print("Email sent! Message ID:", response["MessageId"])
        return {"statusCode": 200, "body": "Email sent successfully"}
    except Exception as e:
        print("Failed to send email:", str(e))
        return {"statusCode": 500, "body": f"Email failed: {str(e)}"}
