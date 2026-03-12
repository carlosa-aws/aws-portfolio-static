import json
import boto3
import os
from datetime import datetime, timezone
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

COOLDOWN_SECONDS = 60


def lambda_handler(event, context):
    ip = event["requestContext"]["http"]["sourceIp"]
    now = int(datetime.now(timezone.utc).timestamp())
    threshold = now - COOLDOWN_SECONDS

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
                OR last_visit < :threshold
                OR last_ip <> :ip
            """,
            ExpressionAttributeValues={
                ":start": 0,
                ":inc": 1,
                ":ip": ip,
                ":now": now,
                ":threshold": threshold
            },
            ReturnValues="UPDATED_NEW"
        )

        count = int(response["Attributes"]["visit_count"])

    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            response = table.get_item(Key={"id": "visits"})
            count = int(response.get("Item", {}).get("visit_count", 0))
        else:
            print("DynamoDB error:", str(e))
            raise

    return {
        "statusCode": 200,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Content-Type": "application/json"
        },
        "body": json.dumps({"visitorCount": count})
    }
