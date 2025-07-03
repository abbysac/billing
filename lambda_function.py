import json
import boto3
import decimal

ses = boto3.client('ses')
ssm = boto3.client('ssm')
budgets = boto3.client('budgets')

SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    print("Received Event:", json.dumps(event, indent=2))

    try:
        sns_message = event["Records"][0]["Sns"]["Message"]
        print(f"Raw SNS Message: {sns_message}")
        if not sns_message or not isinstance(sns_message, str):
            return {"statusCode": 400, "body": "Empty or invalid SNS message"}
        message = json.loads(sns_message)
    except Exception as e:
        print(f"[ERROR] Failed to parse SNS message: {e}")
        return {"statusCode": 400, "body": f"Invalid SNS format: {str(e)}"}

    # ✅ Prevent recursion
    if message.get("source") == "automation":
        print("[INFO] Skipping alert triggered by automation to avoid recursion.")
        return {"statusCode": 200, "body": "Ignored automation message"}

    try:
        account_id = message.get("account_id")
        budget_name = message.get("budgetName")
        threshold = float(message.get("threshold", 80.0))
        environment = message.get("environment", "dev")

        # Dynamic budget fetch fallback
        actual_spend = message.get("actual_spend")
        budget_limit = message.get("budgetLimit")

        if actual_spend is None or budget_limit is None:
            print("[INFO] Budget values missing in SNS — fetching dynamically from Budgets API")
            response = budgets.describe_budget(AccountId=account_id, BudgetName=budget_name)
            budget = response["Budget"]
            budget_limit = float(budget["BudgetLimit"]["Amount"])
            actual_spend = float(budget["CalculatedSpend"]["ActualSpend"]["Amount"])

        percent_used = (actual_spend / budget_limit) * 100 if budget_limit > 0 else 0
        print(f"[INFO] Budget: {budget_name} - {percent_used:.2f}% used")

        if percent_used >= threshold:
            response = ssm.start_automation_execution(
                DocumentName='budget_update_gha_alert',
                Parameters={'TargetAccountId': [account_id]}
            )
            print("SSM Automation triggered:", response)

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

        ses.send_email(
            Source=SENDER_EMAIL,
            Destination={'ToAddresses': [RECIPIENT_EMAIL]},
            Message={
                'Subject': {'Data': subject},
                'Body': {
                    'Text': {'Data': email_body, 'Charset': 'UTF-8'}
                }
            }
        )
        print("Email sent.")
        return {"statusCode": 200, "body": "Alert processed and email sent."}

    except Exception as e:
        print(f"Error in handler: {str(e)}")
        return {"statusCode": 500, "body": f"Internal error: {str(e)}"}
