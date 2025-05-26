import json
import boto3
import os
import decimal

ses = boto3.client('ses', region_name="us-east-1")

SENDER_EMAIL = "abbysac@gmail.com"  # SES-verified email
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def get_nested_value(d, path, default=0.0):
    try:
        for key in path:
            d = d[key]
        return float(d or 0)
    except (KeyError, TypeError, ValueError):
        return default

def lambda_handler(event, context):
    print("Received Event:", json.dumps(event, indent=2))

    # Extract SNS message
    if "Records" in event and isinstance(event["Records"], list):
        try:
            sns_message = event["Records"][0]["Sns"]["Message"]
            message = json.loads(sns_message)
        except (KeyError, IndexError, json.JSONDecodeError) as e:
            print(f"Error parsing SNS message: {str(e)}")
            return {"statusCode": 400, "body": "Invalid SNS event format"}
    else:
        print("Direct Budget event received, using raw event.")
        message = event

    environment = message.get("environment", "dev")
    account_id = message.get("accountId", "")
    budget_name = message.get("budgetName") or message.get("BudgetName") or  "Unknown Budget" 
    alert_type = message.get("alertType", "ACTUAL")

    # Get budget limit and actual spend safely
    budget_limit = get_nested_value(message, ["BudgetLimit", "Amount"])
    actual_spend = get_nested_value(message, ["CalculatedSpend", "ActualSpend", "Amount"])
    percent_used = (actual_spend / budget_limit * 100) if budget_limit else 0.0
    # print("Raw message payload:", json.dumps(message, indent=2))


    subject = f"AWS Budget Alert: {budget_name}"

    if budget_limit > 0:
        threshold_info = (
            f'The actual cost accrued yesterday in "{environment}" has exceeded '
            f"{percent_used:.1f}% of the monthly budget of ${budget_limit:.2f}.\n"
            f"Current actual spend: ${actual_spend:.2f}."
        )
    else:
        threshold_info = f"Actual spend recorded: ${actual_spend:.2f}, but no valid budget limit was found."

    email_body = f"""
{account_id} {budget_name}
Dear System Owner,

#{threshold_info}
this is to notify you that the actual cost accrued yesterday for "{budget_name} in "{environment}" has exceeded
the percentage from the amount of daily value
Please verify your current utilization and cost trajectory. If necessary, update your budget in OMFMgmt.

Thank you,  
OMF CloudOps

Budget Name: {budget_name}  
Account ID:  
Environment: {environment}
budgetLimit: {budget_limit}

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
