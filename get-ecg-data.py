# {
#   "title": "ECGRecord",
#   "type": "object",
#   "properties": {
#     "patient_id": {
#       "type": "string",
#       "description": "Unique identifier for the patient"
#     },
#     "first_name": {
#       "type": "string",
#       "description": "Patient's first name"
#     },
#     "last_name": {
#       "type": "string",
#       "description": "Patient's last name"
#     },
#     "sex": {
#       "type": "string",
#       "enum": ["male", "female", "other", "unknown"],
#       "description": "Patient's sex"
#     },
#     "age": {
#       "type": "integer",
#       "minimum": 0,
#       "description": "Patient's age in years"
#     },
#     "ecg_timestamp": {
#       "type": "string",
#       "format": "date-time",
#       "description": "Timestamp when the ECG was captured"
#     },
#     "ecg_data": {
#       "type": "array",
#       "description": "Raw ECG data as a series of numerical values",
#       "items": {
#         "type": "number"
#       }
#     }
#   },
#   "required": ["patient_id", "first_name", "last_name", "sex", "age", "ecg_timestamp", "ecg_data"]
# }


import json
import boto3
import datetime
from boto3.dynamodb.conditions import Key, Attr

dynamodb = boto3.resource('dynamodb')
TABLE_NAME = "ccc-ecg-data"

def lambda_handler(event, context):
    try:
        if 'body' in event:
                body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        # Extract required fields
        patient_id = body.get("patient_id")
        first_name = body.get("first_name")
        last_name = body.get("last_name")
        sex = body.get("sex")
        age = body.get("age")
        # ecg_timestamp = body.get("ecg_timestamp")
        # ecg_data = body.get("ecg_data")


        table = dynamodb.Table(TABLE_NAME)
        
        # Store data in DynamoDB
        # readings = table.get_item(
        #     Item={
        #         'patient_id': patient_id
            #     'first_name': first_name,
            #     'last_name': last_name,
            #     'sex': sex,
            #     'age': age,
            #     'ecg_timestamp': ecg_timestamp,
            #     'ecg_data': ecg_data
            # }
        # )
        response = table.query(
            KeyConditionExpression=Key('patient_id').eq(patient_id)
        )
        items = response['Items']

        

        return {
            "statusCode": 200,
            "body": items
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
