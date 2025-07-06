


# --- SSM Automation Document (SSM Step) Sample Invocation ---
# (Terraform or JSON-based SSM Document should call this Lambda as a step)

import boto3
import json
import decimal
import hashlib

# Email Config
SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

# Set up boto3 clients
ses = boto3.client('ses')
ssm = boto3.client('ssm')

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
            # Check if sns_message is a string and not empty
            if not isinstance(sns_message, str) or not sns_message.strip():
                print("Error: SNS message is empty or not a string")
                return {"statusCode": 400, "body": "Invalid SNS message format"}
            # Attempt to parse JSON
            try:
                message = json.loads(sns_message)
            except json.JSONDecodeError as e:
                print(f"Error parsing SNS message as JSON: {str(e)}")
                # Handle non-JSON message if expected
                message = {"raw_message": sns_message}  # Fallback to raw message
        except (KeyError, IndexError) as e:
            print(f"Error accessing SNS message: {str(e)}")
            return {"statusCode": 400, "body": "Invalid SNS event format"}
    else:
        print("Direct Budget event received, using raw event.")
        message = event

    # Rest of your logic
    try:
        # Extract values
        account_id = message.get("account_id", "TargetAccountId")
        budget_name = message.get("budgetName", "BudgetName")
        threshold = float(message.get("threshold", 80.0))
        actual_spend = float(message.get("actual_spend") or 0.0)
        budget_limit = float(message.get("budget_limit") or 1.0)
        environment = message.get("environment", "dev")
        generate_dedupe_key = message.get(account_id, budget_name)
        
        percent_used = (actual_spend / budget_limit) * 100 if budget_limit > 0 else 0

        print(f"[INFO] {account_id} - {budget_name} used {percent_used:.2f}% of budget")
        
    # try:
    #     dedupe_key = generate_dedupe_key(account_id, budget_name)

            #Check if alert was already sent today
        # try:
        #     ssm.get_parameter(Name=dedupe_key)
        #     print(f"[INFO] Duplicate alert suppressed for {dedupe_key}")
        #     # return {"statusCode": 200, "body": "Duplicate alert suppressed"}
        # except ssm.exceptions.ParameterNotFound:
        #         print(f"[INFO] No prior alert found. Proceeding to send alert for {dedupe_key}")
        # except Exception as e:
        #     print(f"Error occurred: {e}")
        # return f"{account_id}:{budget_name}"

# def generate_dedupe_key(account_id, budget_name):
    # return f"{account_id}:{budget_name}"
    # today = datetime.datetime.utcnow().strftime("%Y-%m-%d")
    
    # # SSM Parameter Name pattern
    # return f"/budget-alert/{account_id}/{budget_name}/{today}"  
    
    
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