output "lambda_function_name" {
  description = "Name of the visitor-counter Lambda function"
  value       = aws_lambda_function.visitor_counter.function_name
}

output "lambda_function_arn" {
  description = "ARN of the visitor-counter Lambda function"
  value       = aws_lambda_function.visitor_counter.arn
}

output "lambda_function_url" {
  description = "Public visitor-counter endpoint"
  value       = aws_lambda_function_url.visitor_counter.function_url
}

output "dynamodb_table_name" {
  description = "Name of the visitor-counter DynamoDB table"
  value       = aws_dynamodb_table.view_count.name
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_policy_arn" {
  description = "ARN of the Lambda permissions policy"
  value       = aws_iam_policy.lambda_permissions.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group used by the Lambda function"
  value       = aws_cloudwatch_log_group.lambda.name
}