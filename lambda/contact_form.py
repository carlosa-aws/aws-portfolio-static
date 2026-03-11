import json
import os
import re
import uuid
from datetime import datetime, timezone

import boto3

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

TABLE_NAME = os.environ["TABLE_NAME"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")

table = dynamodb.Table(TABLE_NAME)

EMAIL_REGEX = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def build_response(status_code, body, origin):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": origin,
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "POST,OPTIONS"
        },
        "body": json.dumps(body)
    }


def get_response_origin(event):
    origin = ALLOWED_ORIGIN
    headers = event.get("headers") or {}

    request_origin = headers.get("origin") or headers.get("Origin")

    if ALLOWED_ORIGIN == "*":
        return "*"

    if request_origin == ALLOWED_ORIGIN:
        return request_origin

    return ALLOWED_ORIGIN


def lambda_handler(event, context):
    origin = get_response_origin(event)

    method = (
        event.get("requestContext", {})
        .get("http", {})
        .get("method", "")
        .upper()
    )

    if method == "OPTIONS":
        return build_response(200, {"message": "OK"}, origin)

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return build_response(400, {"message": "Invalid JSON payload."}, origin)

    name = (body.get("name") or "").strip()
    email = (body.get("email") or "").strip()
    message = (body.get("message") or "").strip()
    website = (body.get("website") or "").strip()  # honeypot field

    # Honeypot: pretend success so bots do not learn anything useful
    if website:
        return build_response(200, {"message": "Message submitted successfully."}, origin)

    if not name or not email or not message:
        return build_response(
            400,
            {"message": "Name, email, and message are required."},
            origin
        )

    if len(name) > 100:
        return build_response(400, {"message": "Name must be 100 characters or fewer."}, origin)

    if len(email) > 254:
        return build_response(400, {"message": "Email must be 254 characters or fewer."}, origin)

    if len(message) > 2000:
        return build_response(400, {"message": "Message must be 2000 characters or fewer."}, origin)

    if not EMAIL_REGEX.match(email):
        return build_response(400, {"message": "Invalid email address."}, origin)

    message_id = str(uuid.uuid4())
    submitted_at = datetime.now(timezone.utc).isoformat()

    item = {
        "message_id": message_id,
        "submitted_at": submitted_at,
        "name": name,
        "email": email,
        "message": message
    }

    try:
        table.put_item(Item=item)

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject="New portfolio contact form submission",
            Message=(
                f"New contact form submission\n\n"
                f"Submitted at: {submitted_at}\n"
                f"Message ID: {message_id}\n"
                f"Name: {name}\n"
                f"Email: {email}\n\n"
                f"Message:\n{message}"
            )
        )

        return build_response(
            200,
            {"message": "Message submitted successfully."},
            origin
        )

    except Exception as e:
        print(f"Error saving contact form submission: {str(e)}")
        return build_response(
            500,
            {"message": "Internal server error."},
            origin
        )
