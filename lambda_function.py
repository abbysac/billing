import json
import boto3
import os

ses = boto3.client('ses')

SENDER_EMAIL = os.environ['camleous@yahoo.com']
RECIPIENT_EMAILS = os.environ['camleous@yahoo.com'].split(',')  # comma-separated string

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    for record in event['Records']:
        message = record['Sns']['Message']
        subject = record['Sns']['Subject'] if 'Subject' in record['Sns'] else 'AWS Budget Alert'

        response = ses.send_email(
            Source=SENDER_EMAIL,
            Destination={
                'ToAddresses': RECIPIENT_EMAILS
            },
            Message={
                'Subject': {'Data': subject},
                'Body': {
                    'Text': {'Data': message}
                }
            }
        )
        print("SES send_email response:", response)

    return {"statusCode": 200, "body": "Email sent"}
