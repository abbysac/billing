
import boto3
import json
import decimal

def handler(event, context):
    results = []

    account_id = event.get("TargetAccountId")
    budget_name = event.get("BudgetName")
    threshold_percent = float(event.get("BudgetThresholdPercent", 50.0))

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

    if not all([account_id, budget_name, sns_topic_arn]):
            results.append({
            "account_id": account_id,
            "error": "Missing required inputs: TargetAccountId, BudgetName, or SnsTopicArn"
            })
            return {"results": results}