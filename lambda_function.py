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

def lambda_handler(event, context):
    print("Received Event:", json.dumps(event, indent=2))
# # def process_sns_message(event):    
#     # The SNS message is likely contained within the 'event' structure
#     # Parse the SNS message payload
#     message = json.loads(event['Records'][0]['Sns']['Message'])  #

#     # Access fields within the message
#     subject = message.get('Subject', 'No Subject')
#     body = message.get('Message', 'No message body')

#     print(f"Subject: {subject}")
#     print(f"Body: {body}")

#     # Example usage (assuming 'event' is the input to your script from SSM)
#     # (Replace this with the actual way your SSM script receives the SNS message)
#     event_data = {
#         'Records': [
#             {
#                 'Sns': {
#                     'Message': '{"Subject": "Important Notification", "Message": "This is the message content."}'
#                 }
#             }
#         ]
#     }

#     process_sns_message(event_data)
    
    
    # sns_message = event["Records"][0]["Sns"]["Message"]
    # print(f"Raw SNS Message: '{sns_message}'")

    # if not sns_message.strip():
    #     print("Error: SNS message is empty")
    #     return {"statusCode": 400, "body": "SNS message body is empty"}

    # try:
    #     message = json.loads(sns_message)
    # except json.JSONDecodeError as e:
    #     print(f"Error parsing SNS message as JSON: {str(e)}")
    #     return {"statusCode": 400, "body": f"Malformed SNS message: {str(e)}"}

    
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
   

#     try:
#     # Extract SNS payload
#         sns_record = event['Records'][0]['Sns']
#         sns_message_str = sns_record['Message']
#         message = json.loads(sns_message_str)
#     except Exception as e:
#         print(f"Failed to parse SNS message: {e}")
#         return {
#             "statusCode": 400,
#              "body": "Invalid SNS message format"
#  }

    try:
        # Extract values
        account_id = message.get("account_id")
        budget_name = message.get("budgetName")
        threshold = float(message.get("threshold", 80.0))
        
        actual_spend_raw = message.get("actual_spend")
        budget_limit_raw = message.get("budgetLimit")
        if actual_spend_raw is None or budget_limit_raw is None:
            print("Missing required numeric fields in message:", json.dumps(message, indent=2))
            return {"statusCode": 400, "body": "Missing budget numbers"}

        actual_spend = float(actual_spend_raw)
        budget_limit = float(budget_limit_raw)
          
            
        # actual_spend = float(message.get("actual_spend")) #, 0.0))
        # budget_limit = float(message.get("budgetLimit"))
        environment = message.get("environment", "dev")

        percent_used = (actual_spend / budget_limit) * 100 if budget_limit > 0 else 0

        print(f"[INFO] {account_id} - {budget_name} used {percent_used:.2f}% of budget")

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
        except Exception as e:
            print(f"Failed to send email: {str(e)}")
            return {"statusCode": 500, "body": "Failed to send email"}

            return {"statusCode": 200, "body": "Email sent successfully"}

    except Exception as e:
            print(f"Error in main handler logic: {e}")
            return {"statusCode": 400, "body": "Unexpected processing error"}
