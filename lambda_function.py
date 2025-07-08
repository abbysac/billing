import boto3
import json
import decimal
import datetime
import os
import re

# Email Config
SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

# Set up boto3 clients
ses = boto3.client('ses')
ssm = boto3.client('ssm')
budgets = boto3.client('budgets')
# dynamodb = boto3.resource('dynamodb')
# table = dynamodb.Table('BudgetAlertTracker')

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def get_ssm_parameter(name, default=None):
    try:
        response = ssm.get_parameter(Name=name, WithDecryption=True)
        return response['Parameter']['Value']
    except ssm.exceptions.ParameterNotFound:
        print(f"SSM parameter {name} not found, using default: {default}")
        return default

def is_valid_account_id(account_id):
    """Validate that account_id is a 12-digit string."""
    return isinstance(account_id, str) and re.match(r'^\d{12}$', account_id) is not None

def lambda_handler(event, context):
    print("Received Event:", json.dumps(event, indent=2))
    
    # Extract SNS message
    if "Records" in event and isinstance(event["Records"], list) and event["Records"]:
        try:
            sns_message = event["Records"][0]["Sns"]["Message"]
            print(f"Raw SNS Message: {sns_message}")
            if not isinstance(sns_message, str) or not sns_message.strip():
                print("Error: SNS message is empty or not a string")
                return {"statusCode": 400, "body": "Invalid SNS message format"}
            try:
                message = json.loads(sns_message)
            except json.JSONDecodeError as e:
                print(f"Error parsing SNS message as JSON: {str(e)}")
                return {"statusCode": 400, "body": "Invalid SNS message format"}
        except (KeyError, IndexError) as e:
            print(f"Error accessing SNS message: {str(e)}")
            return {"statusCode": 400, "body": "Invalid SNS event format"}
    else:
        print("Direct Budget event received, using raw event.")
        message = event

    try:
        # Normalize keys
        account_id = (message.get("account_id") or message.get("AccountId") or
                      get_ssm_parameter("/budgets/default/account_id") or
                      os.getenv("DEFAULT_ACCOUNT_ID", "224761220970"))  # Valid fallback
        budget_name = (message.get("budget_name") or message.get("BudgetName") or
                       get_ssm_parameter("/budgets/default/budget_name", "BudgetName"))
        environment = (message.get("environment") or
                       get_ssm_parameter("/budgets/default/environment", os.getenv("ENVIRONMENT", "dev")))
        
        # Validate required fields
        if not is_valid_account_id(account_id):
            print(f"[ERROR] Invalid account_id: {account_id} (must be 12 digits)")
            return {"statusCode": 400, "body": f"Invalid account_id: {account_id}"}
        if not budget_name:
            print(f"[ERROR] Missing budget_name: {budget_name}")
            return {"statusCode": 400, "body": "Missing budget_name"}

        # Numeric fields with validation
        try:
            threshold = float(message.get("threshold_percent") or message.get("threshold") or
                             get_ssm_parameter("/budgets/default/threshold", 80.0))
            if threshold < 0:
                raise ValueError("Threshold cannot be negative")
        except (ValueError, TypeError) as e:
            print(f"Invalid threshold value: {str(e)}")
            return {"statusCode": 400, "body": "Invalid threshold value"}

        actual_spend = message.get("actual_spend") or message.get("amount")
        budget_limit = message.get("budget_limit") or message.get("budgetLimit")

        # Fallback to Budgets API if actual_spend or budget_limit is missing
        if actual_spend is None or budget_limit is None:
            print("[INFO] Fetching budget values from AWS Budgets API")
            try:
                response = budgets.describe_budget(AccountId=account_id, BudgetName=budget_name)
                budget = response["Budget"]
                budget_limit = float(budget["BudgetLimit"]["Amount"])
                actual_spend = float(budget["CalculatedSpend"]["ActualSpend"]["Amount"])
            except Exception as e:
                print(f"[ERROR] Failed to fetch budget data: {str(e)}")
                return {"statusCode": 400, "body": f"Failed to fetch budget data: {str(e)}"}

        try:
            actual_spend = float(actual_spend)
            budget_limit = float(budget_limit)
            if actual_spend < 0:
                raise ValueError("Actual spend cannot be negative")
            if budget_limit <= 0:
                raise ValueError("Budget limit must be positive")
        except (ValueError, TypeError) as e:
            print(f"Invalid numeric values: actual_spend={actual_spend}, budget_limit={budget_limit}, error={str(e)}")
            return {"statusCode": 400, "body": "Invalid numeric values"}

        # Calculate usage
        percent_used = (actual_spend / budget_limit) * 100 if budget_limit > 0 else 0
        print(f"[INFO] {account_id} - {budget_name} used {percent_used:.2f}% of budget")

        # # Check if email was already sent for this budget today
        # today = datetime.datetime.utcnow().strftime('%Y-%m-%d')
        # try:
        #     response = table.get_item(
        #         Key={'account_id': account_id, 'budget_name': budget_name, 'date': today}
        #     )
        #     if 'Item' in response:
        #         print(f"Email already sent for {budget_name} on {today}, skipping.")
        #         return {"statusCode": 200, "body": "Email skipped to prevent duplicates"}
        # except Exception as e:
        #     print(f"Error checking DynamoDB: {str(e)}")

        # Compose email
        subject = f"AWS Budget Alert: {budget_name} ({account_id})"
        email_body = f"""\
Account ID: {account_id}
Budget Name: {budget_name}

Dear System Owner,

The actual cost accrued in environment "{environment}" for budget "{budget_name}" has reached:
  - Spend: ${actual_spend:.2f}
  - Budget Limit: ${budget_limit:.2f}
  - Usage: {percent_used:.1f}% (Threshold: {threshold:.1f}%)

If this trend continues, the budget may be exceeded for this period.

Thank you,
OMF CloudOps

---
Full Event Message:
{json.dumps(message, indent=2, cls=DecimalEncoder)}
"""

        # Send Email
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
            # table.put_item(
            #     Item={
            #         'account_id': account_id,
            #         'budget_name': budget_name,
            #         'date': today,
            #         'message_id': response['MessageId'],
            #         'timestamp': datetime.datetime.utcnow().isoformat()
            #     }
            # )
            return {"statusCode": 200, "body": "Email sent successfully"}
        except Exception as e:
            print(f"[ERROR] Failed to send email: {str(e)}")
            return {"statusCode": 500, "body": f"Failed to send email: {str(e)}"}

    except Exception as e:
        print(f"[ERROR] Handler logic failed: {str(e)}")
        return {"statusCode": 400, "body": "Unexpected processing error"}
