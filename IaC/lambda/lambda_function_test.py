import importlib
import json

import boto3
import pytest
from moto import mock_aws


TABLE_NAME = "CloudResumeViewCount"
AWS_REGION = "us-east-1"


@pytest.fixture
def lambda_environment(monkeypatch):
    """
    Creates a mocked DynamoDB table and reloads the Lambda module
    after Moto has started intercepting AWS requests.
    """

    # Dummy credentials prevent boto3 from searching for real credentials.
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")
    monkeypatch.setenv("AWS_SECURITY_TOKEN", "testing")

    monkeypatch.setenv("AWS_REGION", AWS_REGION)
    monkeypatch.setenv("AWS_DEFAULT_REGION", AWS_REGION)
    monkeypatch.setenv("TABLE_NAME", TABLE_NAME)

    with mock_aws():
        dynamodb = boto3.resource(
            "dynamodb",
            region_name=AWS_REGION
        )

        table = dynamodb.create_table(
            TableName=TABLE_NAME,
            KeySchema=[
                {
                    "AttributeName": "id",
                    "KeyType": "HASH"
                }
            ],
            AttributeDefinitions=[
                {
                    "AttributeName": "id",
                    "AttributeType": "S"
                }
            ],
            BillingMode="PAY_PER_REQUEST"
        )

        # Import after Moto starts so the module-level boto3 resource
        # connects to the mocked DynamoDB environment.
        import lambda_function

        lambda_module = importlib.reload(lambda_function)

        yield lambda_module, table


def function_url_event(method: str) -> dict:
    """Create an AWS Lambda Function URL event."""

    return {
        "version": "2.0",
        "requestContext": {
            "http": {
                "method": method
            }
        }
    }


def test_get_increments_existing_view_count(lambda_environment):
    lambda_module, table = lambda_environment

    table.put_item(
        Item={
            "id": "views",
            "count": 5
        }
    )

    response = lambda_module.lambda_handler(
        function_url_event("GET"),
        None
    )

    assert response["statusCode"] == 200
    assert response["headers"]["Content-Type"] == "application/json"

    body = json.loads(response["body"])

    assert body == {"views": 6}

    # Verify that DynamoDB was actually updated.
    stored_item = table.get_item(
        Key={"id": "views"}
    )["Item"]

    assert stored_item["count"] == 6


def test_get_creates_counter_when_item_does_not_exist(
    lambda_environment
):
    lambda_module, table = lambda_environment

    response = lambda_module.lambda_handler(
        function_url_event("GET"),
        None
    )

    assert response["statusCode"] == 200

    body = json.loads(response["body"])

    assert body == {"views": 1}

    stored_item = table.get_item(
        Key={"id": "views"}
    )["Item"]

    assert stored_item["id"] == "views"
    assert stored_item["count"] == 1


@pytest.mark.parametrize(
    "method",
    ["POST", "PUT", "PATCH", "DELETE"]
)
def test_rejects_unsupported_http_methods(
    lambda_environment,
    method
):
    lambda_module, _ = lambda_environment

    response = lambda_module.lambda_handler(
        function_url_event(method),
        None
    )

    assert response["statusCode"] == 405
    assert response["headers"]["Content-Type"] == "application/json"

    body = json.loads(response["body"])

    assert body == {"error": "Method not allowed"}


def test_rejects_event_without_http_method(lambda_environment):
    lambda_module, _ = lambda_environment

    event = {
        "version": "2.0",
        "requestContext": {}
    }

    response = lambda_module.lambda_handler(event, None)

    assert response["statusCode"] == 405

    body = json.loads(response["body"])

    assert body == {"error": "Method not allowed"}


def test_returns_safe_error_when_dynamodb_fails(
    lambda_environment,
    monkeypatch
):
    lambda_module, _ = lambda_environment

    def raise_database_error(**kwargs):
        raise RuntimeError(
            "Sensitive internal database information"
        )

    monkeypatch.setattr(
        lambda_module.table,
        "update_item",
        raise_database_error
    )

    response = lambda_module.lambda_handler(
        function_url_event("GET"),
        None
    )

    assert response["statusCode"] == 500
    assert response["headers"]["Content-Type"] == "application/json"

    body = json.loads(response["body"])

    assert body == {
        "error": "Unable to retrieve visitor count"
    }

    # Confirm that internal exception details are not returned publicly.
    assert "Sensitive internal database information" not in response["body"]


def test_supports_legacy_http_method_event(lambda_environment):
    """
    Your Lambda supports both Function URL/API Gateway v2 events and
    the older event format containing the top-level httpMethod field.
    """

    lambda_module, _ = lambda_environment

    event = {
        "httpMethod": "GET"
    }

    response = lambda_module.lambda_handler(event, None)

    assert response["statusCode"] == 200

    body = json.loads(response["body"])

    assert body == {"views": 1}