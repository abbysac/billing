import json
import boto3
import csv
import io
import decimal
import logging
import re
import traceback
import os
import glob

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# SES Configuration
SENDER_EMAIL = 'abbysac@gmail.com'
AWS_REGION = 'us-east-1'
EMAIL_MAP_FILE = '/var/task/email_map.csv'  # CSV bundled with Lambda package

# Required CSV columns (updated to match new headers)
REQUIRED_COLUMNS = {'AccountId', 'environment', 'email'}

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

def validate_columns(headers):
    """
    Validate that the CSV headers contain all required columns.
    Returns tuple: (is_valid, missing_columns, cleaned_headers)
    """
    cleaned_headers = [h.strip() for h in headers]
    missing = REQUIRED_COLUMNS - set(cleaned_headers)
    return len(missing) == 0, missing, cleaned_headers

def send_ses_email(ses_client, recipient_email, account_id, environment, budget_data=None):
    """
    Send an email via Amazon SES to the recipient.
    Uses budget_data if provided, otherwise sends a test email.
    Returns tuple: (success, message_id or error message)
    """
    try:
        if budget_data:
            subject = f"AWS Budget Alert: {budget_data['budgetName']}"
            email_body = f"""
{account_id} {budget_data['budgetName']}
Dear System Owner,

This is to notify you that the actual cost accrued yesterday in "{environment}" for "{budget_data['budgetName']}" has exceeded
{budget_data['percentage_used']:.1f}% of ${budget_data['budget_limit']:.2f} monthly value of budget. Please verify your
current utilization and cost trajectory. If necessary, please update your annual budget in omfmgmt.

Thank you,
OMF CloudOps

Budget Name: {budget_data['budgetName']}
Account ID: {account_id}
Environment: {environment}
Budget Limit: ${budget_data['budget_limit']:.2f}
Actual Spend: ${budget_data['actual_spend']:.2f}

Full Message:
{json.dumps(budget_data, indent=2, cls=DecimalEncoder)}
"""
        else:
            subject = f"Test Email for Account {account_id} ({environment})"
            email_body = f"""
Hello,

This is a test email for account {account_id} in {environment} environment.

Best regards,
OMF CloudOps
"""
        
        response = ses_client.send_email(
            Source=SENDER_EMAIL,
            Destination={'ToAddresses': [recipient_email]},
            Message={
                'Subject': {'Data': subject, 'Charset': 'UTF-8'},
                'Body': {'Text': {'Data': email_body, 'Charset': 'UTF-8'}}
            }
        )
        logger.info(f"Email sent to {recipient_email}: Message ID {response['MessageId']}")
        return True, response['MessageId']
    except ses_client.exceptions.ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        logger.error(f"Failed to send email to {recipient_email}: {error_code} - {error_message}. Ensure the email is verified in SES.")
        return False, f"{error_code}: {error_message}"
    except Exception as e:
        logger.error(f"Unexpected error sending email to {recipient_email}: {str(e)}")
        return False, str(e)

def parse_sns_event(event):
    """
    Parse SNS or budget event to extract budget data.
    Returns budget_data dict or None if parsing fails.
    """
    try:
        logger.info(f"Received Event: {json.dumps(event, indent=2, cls=DecimalEncoder)}")
        if (
            "Records" in event
            and isinstance(event["Records"], list)
            and event["Records"]
            and "Sns" in event["Records"][0]
            and "Message" in event["Records"][0]["Sns"]
        ):
            sns_message = event["Records"][0]["Sns"]["Message"]
            logger.info(f"Raw SNS Message: {repr(sns_message)}")

            try:
                message = json.loads(sns_message)
            except json.JSONDecodeError:
                logger.warning("Message is not JSON. Using regex-based parser.")
                account_id_match = re.search(r"AWS Account (\d+)", sns_message)
                budget_name_match = re.search(r"Budget Name: ([^\n]+)", sns_message)
                actual_spend_match = re.search(r"ACTUAL Amount: \$?([\d,]+(?:\.\d{1,2})?)", sns_message)
                budget_limit_match = re.search(r"Budgeted Amount: \$?([\d,]+(?:\.\d{1,2})?)", sns_message)
                alert_threshold_match = re.search(r"Alert Threshold: > \$?([\d,]+(?:\.\d{1,2})?)", sns_message)
                environment_match = re.search(r"Environment: ([^\n]+)", sns_message, re.IGNORECASE)

                if not all([account_id_match, budget_name_match, actual_spend_match, budget_limit_match]):
                    logger.error(f"Regex parsing failed for one or more fields: {repr(sns_message)}")
                    return None

                message = {
                    "account_id": account_id_match.group(1),
                    "budgetName": budget_name_match.group(1).strip(),
                    "actual_spend": float(actual_spend_match.group(1).replace(',', '')) if actual_spend_match else 0.0,
                    "budget_limit": float(budget_limit_match.group(1).replace(',', '')) if budget_limit_match else 1.0,
                    "threshold_percent": float(alert_threshold_match.group(1).replace(',', '')) if alert_threshold_match else 80.0,
                    "alert_trigger": "ACTUAL",
                    "environment": environment_match.group(1).strip() if environment_match else "prod"
                }
                if message["budget_limit"] > 0:
                    message["percentage_used"] = (message["actual_spend"] / message["budget_limit"]) * 100
                else:
                    message["percentage_used"] = 0.0
            return message
        elif "messages" in event and isinstance(event["messages"], list) and event["messages"]:
            logger.info("Processing AWS Budgets event")
            budget_event = event["messages"][0]
            message = {
                "account_id": budget_event.get("account_id", "Unknown"),
                "budgetName": budget_event.get("budgetName", "billing-alert"),
                "actual_spend": float(budget_event.get("CalculatedSpend", {}).get("ActualSpend", {}).get("Amount", 0.0)),
                "budget_limit": float(budget_event.get("BudgetLimit", {}).get("Amount", 1.0)),
                "environment": budget_event.get("environment", "prod"),
                "alert_trigger": "ACTUAL",
                "threshold_percent": 80.0
            }
            if message["budget_limit"] > 0:
                message["percentage_used"] = (message["actual_spend"] / message["budget_limit"]) * 100
            else:
                message["percentage_used"] = 0.0
            return message
        else:
            logger.warning("Event does not contain SNS or budget data")
            return None
    except Exception as e:
        logger.error(f"Error parsing event: {str(e)}\n{traceback.format_exc()}")
        return None

def lambda_handler(event, context):
    """
    AWS Lambda handler to process local CSV and send SES emails based on SNS budget alerts.
    """
    ses_client = boto3.client('ses', region_name=AWS_REGION)
    email_results = {'sent': [], 'failed': []}

    # Parse SNS event for budget data
    budget_data = parse_sns_event(event)
    if budget_data:
        logger.info(f"Parsed budget data: {json.dumps(budget_data, cls=DecimalEncoder)}")
        threshold = budget_data.get("threshold_percent", 80.0)
        percentage_used = budget_data.get("percentage_used", 0.0)
        if percentage_used < threshold:
            logger.info(f"Budget usage ({percentage_used:.2f}%) below threshold ({threshold}%) - no emails sent")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Budget threshold not exceeded, no emails sent',
                    'budget_data': budget_data,
                    'emails_sent': [],
                    'emails_failed': []
                }, cls=DecimalEncoder)
            }
    else:
        logger.info("No budget data found, using test email content")

    try:
        # Load CSV from Lambda package
        logger.info(f"Checking file at: {EMAIL_MAP_FILE}")
        logger.info(f"Files in /var/task/: {glob.glob('/var/task/*')}")
        if not os.path.exists(EMAIL_MAP_FILE):
            logger.error(f"CSV file not found at {EMAIL_MAP_FILE}. Email sending aborted.")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': f"CSV file not found at {EMAIL_MAP_FILE}. Please ensure email_map.csv is included in the deployment package.",
                    'emails_sent': [],
                    'emails_failed': []
                }, cls=DecimalEncoder)
            }
        with open(EMAIL_MAP_FILE, 'r', encoding='utf-8') as f:
            csv_content = f.read()
        
        csv_file = io.StringIO(csv_content)
        reader = csv.DictReader(csv_file)

        # Validate and clean headers
        is_valid, missing, cleaned_headers = validate_columns(reader.fieldnames)
        if not is_valid:
            logger.error(f"Invalid CSV format: Missing columns {missing}. Found: {reader.fieldnames}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': f"Invalid CSV format: Missing required columns {missing}.",
                    'emails_sent': [],
                    'emails_failed': []
                }, cls=DecimalEncoder)
            }

        # Process CSV rows and send emails for matching account_id and environment
        rows_processed = 0
        for row in reader:
            recipient_email = row['email'].strip()
            account_id = row['AccountId']  # Updated to match CSV header
            environment = row['environment']
            if not recipient_email:
                logger.warning(f"Skipping empty email for account {account_id}")
                email_results['failed'].append(f"{account_id}: Empty email")
                continue
            # Case-insensitive match for environment
            if budget_data and (
                account_id != budget_data['account_id'] or 
                environment.lower() != budget_data.get('environment', environment).lower()
            ):
                logger.info(f"Skipping email for {recipient_email}: CSV account_id={account_id}, environment={environment} does not match SNS account_id={budget_data['account_id']}, environment={budget_data.get('environment')}")
                continue
            success, result = send_ses_email(ses_client, recipient_email, account_id, environment, budget_data)
            if success:
                email_results['sent'].append(recipient_email)
            else:
                email_results['failed'].append(f"{recipient_email}: {result}")
            rows_processed += 1

        logger.info(f"Processed {rows_processed} rows from CSV")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'CSV processed and emails attempted',
                'rows_processed': rows_processed,
                'headers': reader.fieldnames,
                'emails_sent': email_results['sent'],
                'emails_failed': email_results['failed'],
                'budget_data': budget_data if budget_data else None
            }, cls=DecimalEncoder)
        }

    except Exception as e:
        logger.error(f"Error: {str(e)}\n{traceback.format_exc()}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f"Failed to process CSV or send emails: {str(e)}",
                'error_type': type(e).__name__,
                'emails_sent': email_results['sent'],
                'emails_failed': email_results['failed'],
                'budget_data': budget_data if budget_data else None
            }, cls=DecimalEncoder)
        }