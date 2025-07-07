import boto3
import json
import decimal
import time
import random
import datetime

# Email Config
SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

# Set up boto3 clients
ses = boto3.client('ses')
ssm = boto3.client('ssm')
budgets = boto3.client('budgets')

# Allow decimals in JSON
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)


def lambda_handler(event, context):
    print("Received Event:", json.dumps(event, indent=2))

    # Extract SNS message
    if "Records" in event and isinstance(event["Records"], list) and event["Records"]:
        try:
            sns_message = event["Records"][0]["Sns"]["Message"]
            print(f"Raw SNS Message: {sns_message}")
            if not isinstance(sns_message, str) or not sns_message.strip():
                return {"statusCode": 400, "body": "Invalid SNS message format"}
            try:
                message = json.loads(sns_message)
            except json.JSONDecodeError as e:
                print(f"JSON parse error: {str(e)}")
                message = {"raw_message": sns_message}
        except (KeyError, IndexError) as e:
            print(f"Error accessing SNS message: {str(e)}")
            return {"statusCode": 400, "body": "Invalid SNS event format"}
    else:
        print("Direct Budget event received.")
        message = event

    try:
        # --- Extract values safely ---
        account_id = message.get("account_id", "TargetAccountId")
        budget_name = message.get("budgetName", "BudgetName")
        threshold = float(message.get("threshold", 80.0))
        actual_spend = message.get("actual_spend")
        budget_limit = message.get("budget_limit")
        environment = message.get("environment", "dev")

        # --- If missing values, fallback to Budgets API ---
        if actual_spend is None or budget_limit is None:
            print("[INFO] Fetching budget values from AWS Budgets API")
            response = budgets.describe_budget(AccountId=account_id, BudgetName=budget_name)
            budget = response["Budget"]
            budget_limit = float(budget["BudgetLimit"]["Amount"])
            actual_spend = float(budget["CalculatedSpend"]["ActualSpend"]["Amount"])

        # --- Calculate usage ---
        percent_used = (actual_spend / budget_limit) * 100 if budget_limit > 0 else 0
        print(f"[INFO] {account_id} - {budget_name} used {percent_used:.2f}% of budget")

        # --- Compose Email ---
        subject = f"AWS Budget Alert: {budget_name}"
        email_body = f"""
Account ID: {account_id}
Budget Name: {budget_name}

Dear System Owner,

The actual cost accrued yesterday in "{environment}" for "{budget_name}" has exceeded
{percent_used:.1f}% of the monthly budget of ${budget_limit:.2f}.
Current actual spend: ${actual_spend:.2f}.

Thank you, 
OMF CloudOps

Full Message:
{json.dumps(message, indent=2, cls=DecimalEncoder)}
"""

        # --- Send Email ---
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
            print(f"[SUCCESS] Email sent! Message ID: {response['MessageId']}")
            return {"statusCode": 200, "body": "Email sent successfully"}
        except Exception as e:
            print(f"[ERROR] Failed to send email: {str(e)}")
            return {"statusCode": 500, "body": "Failed to send email"}

    except Exception as e:
        print(f"[ERROR] Handler logic failed: {str(e)}")
        return {"statusCode": 400, "body": "Unexpected processing error"}
