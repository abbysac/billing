import boto3
import json
import decimal

ses = boto3.client('ses')
SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def lambda_handler(event, context):
    print("Received event:", json.dumps(event, indent=2, cls=DecimalEncoder))
    results = []

    try:
        # Parse input
        account_id = event.get("TargetAccountId")
        budget_name = event.get("BudgetName")
        threshold_percent = float(event.get("BudgetThresholdPercent", 80.0))
        environment = event.get("environment", "stage")
        sns_topic_arn = event.get("SnsTopicArn")
        credentials = event.get("Credentials", {})

        if not all([account_id, budget_name, threshold_percent, sns_topic_arn]):
            return {
                "statusCode": 400,
                "body": "Missing required inputs: TargetAccountId, BudgetName, BudgetThresholdPercent, or SnsTopicArn"
            }

        # Create session with assumed credentials
        session = boto3.Session(
            aws_access_key_id=credentials["AccessKeyId"],
            aws_secret_access_key=credentials["SecretAccessKey"],
            aws_session_token=credentials["SessionToken"]
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

        print(f"[INFO] {budget_name} | Limit=${budget_limit:.2f}, Spend=${actual_spend:.2f}, Used={percentage_used:.2f}%")

        alert_triggered = percentage_used >= threshold_percent

        if alert_triggered:
            # Publish SNS message
            sns_message = {
                "account_id": account_id,
                "budgetName": budget_name,
                "amount": actual_spend,
                "budgetLimit": budget_limit,
                "threshold": threshold_percent,
                "alertType": "ACTUAL",
                "environment": environment
            }

            sns.publish(
                TopicArn=sns_topic_arn,
                Message=json.dumps(sns_message)
            )
            print(f"[SNS] Alert published for {budget_name}")

            # Compose and send email
            subject = f"AWS Budget Alert: {budget_name}"
            email_body = f"""
Dear System Owner,

The actual cost accrued yesterday in "{environment}" for "{budget_name}" has exceeded
{percentage_used:.1f}% of the monthly budget of ${budget_limit:.2f}.
Current actual spend: ${actual_spend:.2f}.

Thank you,
OMF CloudOps

Budget Name: {budget_name}
Account ID: {account_id}
Environment: {environment}

Full Message:
{json.dumps(sns_message, indent=2, cls=DecimalEncoder)}
"""

            try:
                email_response = ses.send_email(
                    Source=SENDER_EMAIL,
                    Destination={"ToAddresses": [RECIPIENT_EMAIL]},
                    Message={
                        "Subject": {"Data": subject},
                        "Body": {
                            "Text": {
                                "Data": email_body,
                                "Charset": "UTF-8"
                            }
                        }
                    }
                )
                print(f"[SES] Email sent: {email_response['MessageId']}")
            except Exception as e:
                print(f"[SES ERROR] Failed to send email: {str(e)}")

        results.append({
            "account_id": account_id,
            "budget_name": budget_name,
            "budget_limit": budget_limit,
            "actual_spend": actual_spend,
            "percent_used": percentage_used,
            "alert_triggered": alert_triggered
        })

        return {"statusCode": 200, "body": json.dumps(results, indent=2)}

    except Exception as e:
        print(f"[ERROR] {str(e)}")
        return {"statusCode": 500, "body": str(e)}
