# import json
# import boto3
# import os
# import logging

# logger = logging.getLogger()
# logger.setLevel(logging.INFO)

# ssm = boto3.client("ssm")

# DOCUMENT_NAME = os.environ["SSM_DOCUMENT_NAME"]


# def lambda_handler(event, context):

#     logger.info(f"Incoming event: {json.dumps(event)}")

#     if "Records" not in event:
#         logger.warning("Not an SNS event. Exiting.")
#         return {"status": "not_sns"}

#     for record in event["Records"]:

#         try:
#             message = json.loads(record["Sns"]["Message"])
#         except Exception:
#             logger.warning("SNS message is not JSON. Skipping.")
#             continue

#         budget_name = message.get("budgetName")
#         account_id = message.get("accountId")

#         if not budget_name or not account_id:
#             logger.warning("Missing budgetName or accountId.")
#             continue

#         logger.info(f"Starting SSM automation for {budget_name} in {account_id}")

#         response = ssm.start_automation_execution(
#             DocumentName=DOCUMENT_NAME,
#             Parameters={
#                 "TargetAccountId": [account_id],
#                 "BudgetName": [budget_name]
#             }
#         )

#         logger.info(f"Started AutomationExecutionId: {response['AutomationExecutionId']}")

#     return {"status": "started"}