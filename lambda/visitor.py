

import json
import boto3
import os
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get("TABLE_NAME"))

# Helper function to convert Decimal to int
def decimal_default(obj):
    if isinstance(obj, Decimal):
        return int(obj)
    raise TypeError

def lambda_handler(event, context):
    print("TABLE_NAME =", os.environ.get("TABLE_NAME"))

    response = table.update_item(
        Key={'id': 'visits'},
        UpdateExpression="SET visit_count = if_not_exists(visit_count, :start) + :inc",
        ExpressionAttributeValues={
            ':start': 0,
            ':inc': 1
        },
        ReturnValues="UPDATED_NEW"
    )

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(response['Attributes'], default=decimal_default)
    }
