import json
import boto3
import os
from datetime import datetime, timezone
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

COOLDOWN_SECONDS = 60


def get_source_ip(event):
    request_context = event.get("requestContext", {})

    http_info = request_context.get("http", {})
    if http_info.get("sourceIp"):
        return http_info["sourceIp"]

    identity_info = request_context.get("identity", {})
    if identity_info.get("sourceIp"):
        return identity_info["sourceIp"]

    headers = event.get("headers", {}) or {}
    forwarded_for = headers.get("x-forwarded-for") or headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()

    return "unknown"


def lambda_handler(event, context):
    ip = get_source_ip(event)
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
