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

def get_ssm_parameter(name, default=None):
    """Fetch a parameter from SSM Parameter Store with a fallback default."""
    try:
        response = ssm.get_parameter(Name=name, WithDecryption=True)
        return response['Parameter']['Value']
    except ssm.exceptions.ParameterNotFound:
        print(f"SSM parameter {name} not found, using default: {default}")
        return default

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
        # Dynamically extract values with fallbacks from SSM or environment variables
        account_id = message.get("account_id") or get_ssm_parameter("/budgets/default/account_id", "Unknown")
        budget_name = message.get("budgetName") or get_ssm_parameter("/budgets/default/budget_name", "UnknownBudget")
        environment = message.get("environment") or get_ssm_parameter("/budgets/default/environment", os.getenv("ENVIRONMENT", "dev"))

        # Numeric fields with validation
        try:
            threshold = float(message.get("threshold_percent") or message.get("threshold", get_ssm_parameter("/budgets/default/threshold", 80.0)))
            if threshold < 0:
                raise ValueError("Threshold cannot be negative")
        except (ValueError, TypeError) as e:
            print(f"Invalid threshold value: {str(e)}")
            return {"statusCode": 400, "body": "Invalid threshold value"}

        try:
            actual_spend = float(message.get("actual_spend") or message.get("amount", get_ssm_parameter("/budgets/default/actual_spend", 0.0)))
            if actual_spend < 0:
                raise ValueError("Actual spend cannot be negative")
        except (ValueError, TypeError) as e:
            print(f"Invalid actual_spend value: {str(e)}")
            return {"statusCode": 400, "body": "Invalid actual spend value"}

        try:
            budget_limit = float(message.get("budget_limit") or message.get("budgetLimit", get_ssm_parameter("/budgets/default/budget_limit", 1.0)))
            if budget_limit <= 0:
                raise ValueError("Budget limit must be positive")
        except (ValueError, TypeError) as e:
            print(f"Invalid budget_limit value: {str(e)}")
            return {"statusCode": 400, "body": "Invalid budget limit value"}

        percent_used = (actual_spend / budget_limit) * 100 if budget_limit > 0 else 0

        print(f"[INFO] {account_id} - {budget_name} used {percent_used:.2f}% of budget")

        # Trigger SSM Automation if over threshold
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
            return {"statusCode": 200, "body": "Email sent successfully"}
        except Exception as e:
            print(f"Failed to send email: {str(e)}")
            return {"statusCode": 500, "body": "Failed to send email"}

    except Exception as e:
        print(f"Error in main handler logic: {e}")
        return {"statusCode": 400, "body": "Unexpected processing error"}