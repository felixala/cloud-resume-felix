variable "aws_region" {
  description = "AWS Region for the cloud resume backend"
  type        = string
  default     = "us-east-1"
}

variable "lambda_function_name" {
  description = "Name of the visitor-counter Lambda function"
  type        = string
  default     = "CloudResumeViewCountFunction"
}

variable "lambda_execution_role_name" {
  description = "Name of the IAM execution role used by Lambda"
  type        = string
  default     = "iam_for_lambda"
}

variable "lambda_policy_name" {
  description = "Name of the managed IAM policy attached to Lambda"
  type        = string
  default     = "aws_iam_policy_for_terraform_resume_project_policy"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB visitor-counter table"
  type        = string
  default     = "CloudResumeViewCount"
}

variable "lambda_runtime" {
  description = "Python runtime for the Lambda function"
  type        = string
  default     = "python3.13"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "lambda_memory_size" {
  description = "Lambda memory allocation in MB"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period"
  type        = number
  default     = 14
}

variable "allowed_origins" {
  description = "Origins permitted to call the Lambda Function URL"
  type        = list(string)

  default = [
    "https://felix-laura.com",
    "https://www.felix-laura.com"
  ]
}

variable "common_tags" {
  description = "Tags applied to AWS resources"
  type        = map(string)

  default = {
    Project     = "Cloud Resume Challenge"
    Environment = "production"
    ManagedBy   = "Terraform"
    Owner       = "Felix Laura"
  }
}