import boto3
import json
import datetime
import urllib.parse
import decimal

ses = boto3.client('ses')
ssm = boto3.client('ssm')

def handler(event, context):
    results = []
    account_id = event.get("AccountId")
    budget_names = event.get("BudgetName")
    sns_topic_arn = event.get("SnsTopicArn", "")
    message = event.get("Message", "Budget threshold exceeded")
    credentials = event.get("Credentials", {})

    print(f"Input event: {json.dumps(event, indent=2)}")

    if isinstance(budget_names, str):
        budget_names = [budget_names]
    elif not isinstance(budget_names, list) or not budget_names:
        return {"results": [{"account_id": account_id, "error": "BudgetName must be a non-empty string or list"}]}

    if not all([account_id, budget_names, sns_topic_arn, credentials]):
        return {"results": [{"account_id": account_id, "error": "Missing required inputs"}]}

    try:
        session = boto3.Session(
            aws_access_key_id=credentials["AccessKeyId"],
            aws_secret_access_key=credentials["SecretAccessKey"],
            aws_session_token=credentials["SessionToken"]
        )
        budgets = session.client("budgets")
        sns = session.client("sns")
        ssm = session.client("ssm")

        for budget_name in budget_names:
            try:
                response = budgets.describe_budget(AccountId=account_id, BudgetName=budget_name)
                budget = response["Budget"]
                budget_limit = float(budget["BudgetLimit"]["Amount"])
                actual_spend = float(budget["CalculatedSpend"]["ActualSpend"]["Amount"])
                percentage_used = (actual_spend / budget_limit) * 100 if budget_limit else 0

                print(f"[{budget_name}] Limit: {budget_limit}, Spend: {actual_spend}, Used: {percentage_used:.2f}%")

                threshold_percent = 80.0
                alert_trigger = "ACTUAL"
                alert_triggered = percentage_used >= threshold_percent

                if alert_triggered:
                    # Deduplication logic — store alert marker in SSM
                    param_name = f"/budget-alerts/{account_id}/{urllib.parse.quote(budget_name)}"

                    try:
                        existing = ssm.get_parameter(Name=param_name)
                        print(f"Alert already sent for {budget_name}, skipping SNS.")
                        results.append({"account_id": account_id, "budget_name": budget_name, "status": "skipped"})
                        continue  # Skip SNS if already alerted
                    except ssm.exceptions.ParameterNotFound:
                        pass  # Expected

                    payload = {
                        "account_id": account_id,
                        "budgetName": budget_name,
                        "actual_spend": actual_spend,
                        "budget_limit": budget_limit,
                        "percentage_used": percentage_used,
                        "alert_trigger": alert_trigger,
                        "environment": "stage",
                        "message": message,
                        "Subject": "Budget Alert",
                        "threshold_percent": threshold_percent
                    }

                    sns_response = sns.publish(
                        TopicArn=sns_topic_arn,
                        Message=json.dumps(payload)
                    )
                    print(f"SNS published for {budget_name}. MessageId: {sns_response['MessageId']}")

                    ssm.put_parameter(
                        Name=param_name,
                        Value=json.dumps({
                            "message_id": sns_response["MessageId"],
                            "timestamp": str(datetime.datetime.utcnow())
                        }),
                        Type="String"
                    )

                results.append({
                    "account_id": account_id,
                    "budget_name": budget_name,
                    "budget_limit": budget_limit,
                    "actual_spend": actual_spend,
                    "percent_used": percentage_used,
                    "alert_triggered": alert_triggered
                })

            except Exception as e:
                print(f"Error with budget {budget_name}: {e}")
                results.append({"account_id": account_id, "budget_name": budget_name, "error": str(e)})

    except Exception as e:
        print(f"Session error: {e}")
        results.append({"account_id": account_id, "error": str(e)})

    print(f"Final results:\n{json.dumps(results, indent=2)}")
    return {"results": results}


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