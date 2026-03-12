import json
import boto3
import os
from decimal import Decimal
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ.get("TABLE_NAME"))

COOLDOWN_SECONDS = 60


def lambda_handler(event, context):
    ip = event["requestContext"]["http"]["sourceIp"]
    now = int(datetime.now(timezone.utc).timestamp())

    try:
        response = table.update_item(
            Key={"id": "visits"},
            UpdateExpression="""
                SET visit_count = if_not_exists(visit_count, :start) + :inc,
                    last_ip = :ip,
                    last_visit = :now
            """,
            ConditionExpression="""
                attribute_not_exists(last_visit)
                OR :now - last_visit > :cooldown
                OR last_ip <> :ip
            """,
            ExpressionAttributeValues={
                ":start": 0,
                ":inc": 1,
                ":ip": ip,
                ":now": now,
                ":cooldown": COOLDOWN_SECONDS
            },
            ReturnValues="UPDATED_NEW"
        )

        count = int(response["Attributes"]["visit_count"])

    except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
        response = table.get_item(Key={"id": "visits"})
        count = int(response["Item"].get("visit_count", 0))

    return {
        "statusCode": 200,
        "headers": {
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps({"visitorCount": count})
    }
