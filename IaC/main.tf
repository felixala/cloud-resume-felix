# ---------------------------------------------------------
# DynamoDB visitor-counter table
# ---------------------------------------------------------

resource "aws_dynamodb_table" "view_count" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ---------------------------------------------------------
# Lambda execution role
# ---------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "AllowLambdaService"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"

      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "lambda_execution" {
  name               = var.lambda_execution_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# ---------------------------------------------------------
# CloudWatch log group
# ---------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------
# Lambda least-privilege policy
# ---------------------------------------------------------

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid    = "WriteLambdaLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.lambda.arn}:*"
    ]
  }

  statement {
    sid    = "UpdateVisitorCounter"
    effect = "Allow"

    actions = [
      "dynamodb:UpdateItem"
    ]

    resources = [
      aws_dynamodb_table.view_count.arn
    ]
  }
}

resource "aws_iam_policy" "lambda_permissions" {
  name        = var.lambda_policy_name
  description = "Allows the cloud-resume Lambda to update the visitor counter and write logs"
  policy      = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_iam_role_policy_attachment" "lambda_permissions" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_permissions.arn
}

# ---------------------------------------------------------
# Package the Python Lambda source
# ---------------------------------------------------------

data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py"
  output_path = "${path.module}/lambda/lambda_function.zip"
}

# ---------------------------------------------------------
# Lambda function
# ---------------------------------------------------------

resource "aws_lambda_function" "visitor_counter" {
  function_name = var.lambda_function_name

  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  role    = aws_iam_role.lambda_execution.arn
  handler = "lambda_function.lambda_handler"
  runtime = var.lambda_runtime

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.view_count.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_permissions,
    aws_cloudwatch_log_group.lambda
  ]
}

# ---------------------------------------------------------
# Public Lambda Function URL
# ---------------------------------------------------------

resource "aws_lambda_function_url" "visitor_counter" {
  function_name      = aws_lambda_function.visitor_counter.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = var.allowed_origins
    allow_methods     = ["GET"]
    allow_headers     = ["content-type"]
    max_age           = 86400
  }
}