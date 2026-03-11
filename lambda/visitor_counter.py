import json
import boto3
import os
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    print("TABLE_NAME =", os.environ.get("TABLE_NAME"))

    response = table.update_item(
        Key={"id": "visits"},
        UpdateExpression="SET visit_count = if_not_exists(visit_count, :start) + :inc",
        ExpressionAttributeValues={
            ":start": 0,
            ":inc": 1
        },
        ReturnValues="UPDATED_NEW"
    )

    count = response["Attributes"]["visit_count"]

    if isinstance(count, Decimal):
        count = int(count)

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({
            "visitorCount": count
        })
    }
