import boto3
import decimal
import logging
import json
import botocore.exceptions
import time
import datetime
import re

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Set up boto3 clients
ses = boto3.client('ses', region_name='us-east-1')
ssm = boto3.client('ssm')
budgets = boto3.client('budgets')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('BudgetAlertTracker')

SENDER_EMAIL = "abbysac@gmail.com"
RECIPIENT_EMAIL = "camleous@yahoo.com"

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def get_ssm_parameter(name, default=None):
    try:
        response = ssm.get_parameter(Name=name, WithDecryption=True)
        return response['Parameter']['Value']
    except (ssm.exceptions.ParameterNotFound, ssm.exceptions.ClientError) as e:
        logger.warning(f"Failed to get SSM parameter {name}: {str(e)}, using default: {default}")
        return default

def is_valid_account_id(account_id):
    """Validate that account_id is a 12-digit string."""
    return isinstance(account_id, str) and re.match(r'^\d{12}$', account_id) is not None

def is_valid_budget_name(budget_name, account_id):
    """Check if budget_name exists in AWS Budgets."""
    try:
        budgets.describe_budget(AccountId=account_id, BudgetName=budget_name)
        return True
    except budgets.exceptions.NotFoundException:
        logger.warning(f"Budget {budget_name} does not exist for account {account_id}")
        return False
    except Exception as e:
        logger.error(f"Error validating budget {budget_name}: {str(e)}")
        return False

def send_email_with_retries(email_params, retries=2, delay=1):
    for attempt in range(1, retries + 1):
        try:
            response = ses.send_email(**email_params)
            return response
        except botocore.exceptions.ClientError as e:
            if e.response['Error']['Code'] == 'Throttling':
                logger.warning(f"SES throttled. Attempt {attempt} of {retries}. Retrying in {delay} seconds...")
                time.sleep(delay)
                delay *= 2
            else:
                raise
    raise Exception("Exceeded retry limit due to SES throttling")

def parse_aws_budget_notification(text):
    """Parse AWS Budgets plain text notification."""
    try:
        # Extract fields using regex with more robust patterns
        account_id_match = re.search(r'AWS Account (\d{12})', text)
        budget_name_match = re.search(r'Budget Name: (.+?)(?:\n|$)', text, re.MULTILINE)
        actual_spend_match = re.search(r'ACTUAL Amount: \$([\d.]+)', text)
        budget_limit_match = re.search(r'Budgeted Amount: \$([\d.]+)', text)
        alert_trigger_match = re.search(r'Alert Type: (\w+)', text)
        threshold_match = re.search(r'Alert Threshold: > \$([\d.]+)', text)

        # Validate matches
        if not all([account_id_match, budget_name_match, actual_spend_match, budget_limit_match]):
            logger.error(f"Missing required fields in AWS Budgets notification: {repr(text)}")
            return None

        account_id = account_id_match.group(1)
        budget_name = budget_name_match.group(1).strip()
        actual_spend = float(actual_spend_match.group(1))
        budget_limit = float(budget_limit_match.group(1))
        alert_trigger = alert_trigger_match.group(1) if alert_trigger_match else 'ACTUAL'
        threshold = float(threshold_match.group(1)) if threshold_match else None

        # Calculate threshold_percent
        threshold_percent = (threshold / budget_limit * 100) if threshold and budget_limit else (actual_spend / budget_limit * 100 if budget_limit else None)

        result = {
            'account_id': account_id,
            'budget_name': budget_name,
            'actual_spend': actual_spend,
            'budget_limit': budget_limit,
            'alert_trigger': alert_trigger,
            'threshold_percent': threshold_percent,
            'environment': get_ssm_parameter("/budgets/default/environment", "stage")
        }
        logger.info(f"Parsed AWS Budgets notification: {json.dumps(result, indent=2)}")
        return result if all([result['account_id'], result['budget_name'], result['actual_spend'], result['budget_limit'], result['threshold_percent']]) else None
    except Exception as e:
        logger.error(f"Failed to parse AWS Budgets notification: {str(e)}, text: {repr(text)}")
        return None

def lambda_handler(event, context):
    logger.info(f"Full event received: {json.dumps(event, indent=2)}")

    # Extract SNS message
    try:
        if isinstance(event, dict) and "Records" in event and event["Records"] and "Sns" in event["Records"][0]:
            sns_message_raw = event["Records"][0]["Sns"]["Message"]
            logger.info("Parsed message from SNS event.")
        else:
            logger.warning("No 'Records' or 'Sns' key found. Using raw event as message.")
            sns_message_raw = json.dumps(event) if isinstance(event, dict) else str(event)

        if not sns_message_raw.strip():
            logger.error(f"SNS message is empty or blank: {repr(sns_message_raw)}")
            return {"statusCode": 400, "body": "SNS message is empty or blank"}

        logger.info(f"Attempting to decode SNS message: {repr(sns_message_raw)}")
        
        # Try JSON parsing first
        try:
            message = json.loads(sns_message_raw)
            logger.info(f"Parsed SNS message as JSON: {json.dumps(message, indent=2)}")
        except json.JSONDecodeError:
            # Try parsing as AWS Budgets notification
            logger.info("JSON parsing failed, attempting to parse as AWS Budgets notification")
            message = parse_aws_budget_notification(sns_message_raw)
            if not message:
                logger.error(f"Failed to parse SNS message as JSON or AWS Budgets notification: {repr(sns_message_raw)}")
                return {"statusCode": 400, "body": f"Invalid SNS message format, raw message: {repr(sns_message_raw)}"}

    except Exception as e:
        logger.error(f"Unexpected error parsing SNS message: {str(e)}, raw message: {repr(sns_message_raw)}")
        return {"statusCode": 500, "body": f"Error parsing SNS message: {str(e)}"}

    # Extract and validate budget details
    try:
        account_id = (message.get("account_id") or message.get("TargetAccountId") or
                      get_ssm_parameter("/budgets/default/account_id", "224761220970"))
        budget_name = (message.get("budget_name") or message.get("BudgetName") or
                       get_ssm_parameter("/budgets/default/budget_name", "ABC Operations DEV Account Overall Budget"))
        environment = (message.get("environment") or
                       get_ssm_parameter("/budgets/default/environment", "stage"))
        alert_trigger = (message.get("alert_trigger") or message.get("AlertTrigger") or
                         message.get("alertType", "ACTUAL"))

        # Validate required fields
        if not is_valid_account_id(account_id):
            logger.error(f"Invalid account_id: {account_id} (must be 12 digits)")
            return {"statusCode": 400, "body": f"Invalid account_id: {account_id}"}
        if not budget_name:
            logger.error(f"Missing budget_name: {budget_name}")
            return {"statusCode": 400, "body": "Missing budget_name"}

        # Validate budget_name
        if not is_valid_budget_name(budget_name, account_id):
            logger.error(f"Invalid budget_name: {budget_name} does not exist for account {account_id}")
            return {"statusCode": 400, "body": f"Budget {budget_name} does not exist for account {account_id}"}

        # Numeric fields with validation
        try:
            threshold = float(message.get("threshold_percent") or message.get("AlertThreshold") or
                             get_ssm_parameter("/budgets/default/threshold", 80.0))
            if threshold < 0:
                raise ValueError("Threshold cannot be negative")
        except (ValueError, TypeError) as e:
            logger.error(f"Invalid threshold value: {str(e)}")
            return {"statusCode": 400, "body": f"Invalid threshold value: {str(e)}"}

        actual_spend = message.get("actual_spend") or message.get("ActualSpend") or message.get("actualAmount")
        budget_limit = message.get("budget_limit") or message.get("BudgetLimit") or message.get("budgetLimit")

        # Fallback to Budgets API if actual_spend or budget_limit is missing
        if actual_spend is None or budget_limit is None:
            logger.info("[INFO] Fetching budget values from AWS Budgets API")
            try:
                response = budgets.describe_budget(AccountId=account_id, BudgetName=budget_name)
                budget = response["Budget"]
                budget_limit = float(budget["BudgetLimit"]["Amount"])
                actual_spend = float(budget["CalculatedSpend"]["ActualSpend"]["Amount"])
            except Exception as e:
                logger.error(f"Failed to fetch budget data: {str(e)}")
                return {"statusCode": 400, "body": f"Failed to fetch budget data: {str(e)}"}

        try:
            actual_spend = float(actual_spend)
            budget_limit = float(budget_limit)
            if actual_spend < 0:
                raise ValueError("Actual spend cannot be negative")
            if budget_limit <= 0:
                raise ValueError("Budget limit must be positive")
        except (ValueError, TypeError) as e:
            logger.error(f"Invalid numeric values: actual_spend={actual_spend}, budget_limit={budget_limit}, error={str(e)}")
            return {"statusCode": 400, "body": f"Invalid numeric values: {str(e)}"}

        percentage_used = (actual_spend / budget_limit) * 100 if budget_limit > 0 else 0
        logger.info(f"{account_id} - {budget_name} used {percentage_used:.2f}% of budget, threshold: {threshold}%")

        # Check if email was already sent for this budget today
        today = datetime.datetime.utcnow().strftime('%Y-%m-%d')
        try:
            response = table.get_item(
                Key={'account_id': account_id, 'budget_name': budget_name, 'date': today}
            )
            if 'Item' in response:
                logger.info(f"Email already sent for {budget_name} on {today}, skipping.")
                return {"statusCode": 200, "body": "Email skipped to prevent duplicates"}
        except Exception as e:
            logger.error(f"Error checking DynamoDB: {str(e)}")

        if percentage_used < threshold:
            logger.info(f"{budget_name} usage ({percentage_used:.2f}%) below threshold ({threshold}%) - no email sent")
            return {"statusCode": 200, "body": "Threshold not exceeded"}

        # Compose email
        subject = f"AWS Budget Alert: {budget_name}"
        email_body = f"""
Account ID: {account_id}
Budget Name: {budget_name}

Dear System Owner,

The actual cost accrued in environment "{environment}" for budget "{budget_name}" has reached:
  - Spend: ${actual_spend:.2f}
  - Budget Limit: ${budget_limit:.2f}
  - Usage: {percentage_used:.1f}% (Threshold: {threshold:.1f}%)

If this trend continues, the budget may be exceeded for this period.

Thank you,
OMF CloudOps

---
Budget Name: {budget_name}
Account ID: {account_id}
Environment: {environment}
Budget Limit: ${budget_limit:.2f}
Alert Trigger: {alert_trigger}

Full Message:
{json.dumps(message, indent=2, cls=DecimalEncoder)}
"""

        # Send email with retries
        email_params = {
            'Source': SENDER_EMAIL,
            'Destination': {'ToAddresses': [RECIPIENT_EMAIL]},
            'Message': {
                'Subject': {'Data': subject},
                'Body': {
                    'Text': {
                        'Data': email_body,
                        'Charset': 'UTF-8'
                    }
                }
            }
        }
        try:
            response = send_email_with_retries(email_params)
            logger.info(f"Email sent! Message ID: {response['MessageId']}")
            table.put_item(
                Item={
                    'account_id': account_id,
                    'budget_name': budget_name,
                    'date': today,
                    'message_id': response['MessageId'],
                    'timestamp': datetime.datetime.utcnow().isoformat()
                }
            )
            return {"statusCode": 200, "body": "Email sent successfully"}
        except Exception as e:
            logger.error(f"Failed to send email: {str(e)}")
            return {"statusCode": 500, "body": f"Failed to send email: {str(e)}"}

    except Exception as e:
        logger.error(f"Error in main handler logic: {str(e)}")
        return {"statusCode": 500, "body": f"Unexpected processing error: {str(e)}"}
