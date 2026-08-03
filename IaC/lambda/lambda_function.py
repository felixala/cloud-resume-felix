import json
import logging
import os
from decimal import Decimal
from typing import Any

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ.get("TABLE_NAME", "CloudResumeViewCount")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
table = dynamodb.Table(TABLE_NAME)


def decimal_default(value: Any) -> int | float:
    """Convert DynamoDB Decimal values into JSON-compatible numbers."""
    if isinstance(value, Decimal):
        if value % 1 == 0:
            return int(value)
        return float(value)

    raise TypeError(f"Object of type {type(value).__name__} is not JSON serializable")


def build_response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    """Create a Lambda Function URL-compatible HTTP response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(body, default=decimal_default)
    }


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    """Increment and return the cloud resume visitor count."""
    logger.info("Visitor-counter request received")

    try:
        http_method = (
            event.get("httpMethod")
            or event.get("requestContext", {})
            .get("http", {})
            .get("method")
        )

        if http_method != "GET":
            return build_response(
                405,
                {"error": "Method not allowed"}
            )

        response = table.update_item(
            Key={"id": "views"},
            UpdateExpression="SET #count = if_not_exists(#count, :start) + :increment",
            ExpressionAttributeNames={
                "#count": "count"
            },
            ExpressionAttributeValues={
                ":start": 0,
                ":increment": 1
            },
            ReturnValues="UPDATED_NEW"
        )

        view_count = response["Attributes"]["count"]

        return build_response(
            200,
            {"views": view_count}
        )

    except Exception:
        logger.exception("Unable to update visitor count")

        return build_response(
            500,
            {"error": "Unable to retrieve visitor count"}
        )