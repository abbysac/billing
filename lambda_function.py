import json
import boto3
import os

ses = boto3.client('ses')

SENDER_EMAIL = os.environ['SENDER_EMAIL']
RECIPIENT_EMAILS = os.environ['RECIPIENT_EMAILS'].split(',')

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    for record in event['Records']:
        message = record['Sns']['Message']
        subject = record['Sns'].get('Subject', 'AWS Budget Alert')

        response = ses.send_email(
            Source=SENDER_EMAIL,
            Destination={'ToAddresses': RECIPIENT_EMAILS},
            Message={
                'Subject': {'Data': subject},
                'Body': {'Text': {'Data': message}}
            }
        )

        print("SES send_email response:", response)

    return {"statusCode": 200, "body": "Email sent"}
