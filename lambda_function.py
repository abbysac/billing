
import boto3
import json
import decimal

ses = boto3.client('ses')
ssm = boto3.client('ssm')

SENDER_EMAIL = "abbysac@gmail.com"  # SES-verified email
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)


def handler(event, context):
    results = []
    message = event

    account_id = event.get("TargetAccountId")
    budget_name = event.get("BudgetName")
    threshold_percent = float(event.get("BudgetThresholdPercent", 80.0))
    environment = message.get("environment", "stage")
    # budget_limit = float.get("budgetLimit")
    # actual_spend = float.message.get("actual_spend")
    

    try:
            session = boto3.Session(
            aws_access_key_id=event["Credentials"]["AccessKeyId"],
            aws_secret_access_key=event["Credentials"]["SecretAccessKey"],
            aws_session_token=event["Credentials"]["SessionToken"]
            )

            budgets = session.client("budgets")
            sns = session.client("sns")

            response = budgets.describe_budget(
            AccountId=account_id,
            BudgetName=budget_name
            )

            budget = response["Budget"]
            budget_limit = float(budget["BudgetLimit"]["Amount"])
            actual_spend = float(budget["CalculatedSpend"]["ActualSpend"]["Amount"])
            percentage_used = (actual_spend / budget_limit) * 100 if budget_limit else 0

            alert_triggered = percentage_used >= threshold_percent

            if alert_triggered:
                sns.publish(
                TopicArn=event["SnsTopicArn"],
                Message=json.dumps({
                "accountId": account_id,
                "budgetName": budget_name,
                "amount": actual_spend,
                "budgetLimit": budget_limit,
                "threshold": threshold_percent,
                "alertType": "ACTUAL",
                "environment": "dev"
                })
                )

                results.append({
                    "account_id": account_id,
                    "budget_limit": budget_limit,
                    "actual_spend": actual_spend,
                    "percent_used": percentage_used,
                    "alert_triggered": alert_triggered
                    })

    except Exception as e:
            results.append({"account_id": account_id, "error": str(e)})

            return {"results": results}



    print(f"Processing account: {account_id}, budget: {budget_name}, threshold: {threshold_percent}%")

    if not all([account_id, budget_name, SnsTopicArn]):
            results.append({
            "account_id": account_id,
            "error": "Missing required inputs: TargetAccountId, BudgetName, or SnsTopicArn"
            })
            return {"results": results}
            
    if budget_limit > 0:
        threshold_info = (
         f'The actual cost accrued yesterday in "{environment}" has exceeded '
         f"{ percentage_used:.1f}% of the monthly budget of ${budget_limit:.2f}.\n"
         f"Current actual spend: ${actual_spend:.2f}."
 )
    else:
        threshold_info = f"Actual spend recorded: ${actual_spend:.2f}, but no valid budget limit was found."
subject = f"AWS Budget Alert: {budget_name}"
email_body = f"""
Dear System Owner,

{BudgetThresholdPercent}
The actual cost accrued yesterday in "{environment}" for "{budget_name}" has exceeded the 
{percentage_used:.1f}% of  the monthly budget of ${budget_limit:.2f}.
Please verify your current utilization and cost trajectory. If necessary, update your budget in OMFMgmt.

Thank you, 
OMF CloudOps

Budget Name: {budget_name} 
Account ID: {account_id} 
Environment: {environment}

Full Message:
{json.dumps(message, indent=2, cls=DecimalEncoder)}
"""
    
    # Send plain text email (no HTML, no templates)
          
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
