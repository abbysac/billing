# --- SSM Automation Document (SSM Step) Sample Invocation ---
# (Terraform or JSON-based SSM Document should call this Lambda as a step)

import boto3
import json
import decimal

# Email Config
SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

# Set up boto3 clients
ses = boto3.client('ses')

# Allow decimals in JSON
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    print("Received Event:", json.dumps(event, indent=2))

    # Required parameters from SSM Document
    account_id = event.get("TargetAccountId")
    budget_name = event.get("BudgetName")
    threshold_percent = float(event.get("BudgetThresholdPercent", 80.0))
    environment = event.get("Environment", "dev")

    # Assume credentials passed from automation role
    try:
        session = boto3.Session(
            aws_access_key_id=event["Credentials"]["AccessKeyId"],
            aws_secret_access_key=event["Credentials"]["SecretAccessKey"],
            aws_session_token=event["Credentials"]["SessionToken"]
        )
    except KeyError as e:
        return {"statusCode": 400, "body": f"Missing credentials: {str(e)}"}

    budgets = session.client("budgets")

    try:
        budget_resp = budgets.describe_budget(AccountId=account_id, BudgetName=budget_name)
        budget = budget_resp["Budget"]

        budget_limit = float(budget["BudgetLimit"]["Amount"])
        actual_spend = float(budget["CalculatedSpend"]["ActualSpend"]["Amount"])
        percentage_used = (actual_spend / budget_limit) * 100 if budget_limit else 0

        print(f"[INFO] Budget {budget_name}: Used {percentage_used:.2f}% of ${budget_limit:.2f}")

        if percentage_used >= threshold_percent:
            subject = f"AWS Budget Alert: {budget_name}"
            email_body = f"""
Dear System Owner,

The budget for account {account_id} in environment '{environment}' has exceeded the threshold:

Budget Name: {budget_name}
Budget Limit: ${budget_limit:.2f}
Actual Spend: ${actual_spend:.2f}
Percent Used: {percentage_used:.1f}%

Threshold: {threshold_percent:.1f}%

Thank you,
OMF CloudOps
            """

            ses.send_email(
                Source=SENDER_EMAIL,
                Destination={"ToAddresses": [RECIPIENT_EMAIL]},
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

            return {
                "statusCode": 200,
                "body": f"Alert email sent for {budget_name} at {percentage_used:.2f}% usage"
            }
        else:
            return {
                "statusCode": 200,
                "body": f"Budget {budget_name} at {percentage_used:.2f}% does not exceed threshold"
            }

    except Exception as e:
        print(f"[ERROR] Failed to process budget alert: {str(e)}")
        return {"statusCode": 500, "body": str(e)}
