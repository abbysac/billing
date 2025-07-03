import json
import boto3
import decimal

ses = boto3.client('ses')
ssm = boto3.client('ssm')

SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

budgets_client = boto3.client("budgets")
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
           return float(obj)
        return super().default(obj)

# Helper to fetch budget usage dynamically
def get_budget_usage(account_id, budget_name):
    try:
        response = budgets.describe_budget(AccountId=account_id, BudgetName=budget_name)
        budget = response["budget_name"]
        budget_limit = float(budget["BudgetLimit"]["Amount"])
        actual_spend = float(budget["CalculatedSpend"]["ActualSpend"]["Amount"])
        print(f"[Budget API] {budget_name}: Limit=${budget_limit}, Spend=${actual_spend}")
        return budget_limit, actual_spend
    except Exception as e:
        print(f"[ERROR] Failed to fetch budget usage for {budget_name}: {e}")
        return None, None

# Main Lambda handler
def lambda_handler(event, context):
    print("Received Event:", json.dumps(event, indent=2))

    # Extract SNS payload
    try:
        sns_message = event["Records"][0]["Sns"]["Message"]
        print(f"Raw SNS Message: {sns_message}")
        if not sns_message or not isinstance(sns_message, str):
            return {"statusCode": 400, "body": "Empty or invalid SNS message"}
        message = json.loads(sns_message)
    except Exception as e:
        print(f"[ERROR] Failed to parse SNS message: {e}")
        return {"statusCode": 400, "body": f"Invalid SNS format: {str(e)}"}

    try:
        # Extract core fields
        account_id = message.get("account_id")
        budget_name = message.get("budgetName")
        threshold = float(message.get("threshold", 80.0))
        environment = message.get("environment", "dev")

        if not account_id or not budget_name:
            print("[ERROR] Missing account_id or budgetName in message")
            return {"statusCode": 400, "body": "Missing required fields: account_id or budgetName"}

        # Try to get spend data from SNS first
        actual_spend_raw = message.get("actual_spend")
        budget_limit_raw = message.get("budgetLimit")

        if actual_spend_raw is not None and budget_limit_raw is not None:
            actual_spend = float(actual_spend_raw)
            budget_limit = float(budget_limit_raw)
        else:
            print("[INFO] Budget values missing in SNS — fetching dynamically from Budgets API")
            budget_limit, actual_spend = get_budget_usage(account_id, budget_name)
            if budget_limit is None or actual_spend is None:
                return {"statusCode": 500, "body": "Failed to retrieve budget usage"}

        percent_used = (actual_spend / budget_limit) * 100 if budget_limit > 0 else 0
        print(f"[INFO] Budget: {budget_name} - {percent_used:.2f}% used")
        
        # 🔁 Trigger SSM Automation if over threshold
        if percent_used >= threshold:
            try:
                response = ssm.start_automation_execution(
                DocumentName='budget_update_gha_alert',
                Parameters={'TargetAccountId': [account_id]}
                )
                print("SSM Automation triggered:", response)
            except Exception as e:
                print(f"Failed to start SSM automation: {e}")

            
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

