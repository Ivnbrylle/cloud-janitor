terraform {
  backend "s3" {
    bucket         = "ivan-terraform-state-405483480953" # Use your actual bucket name
    key            = "state/janitor.tfstate"           # Unique key for this project
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-locking"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

# 1. Notification Topic
resource "aws_sns_topic" "janitor_alerts" {
  name = "cloud-janitor-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.janitor_alerts.arn
  protocol  = "email"
  endpoint  = "your-gmail@gmail.com" # Put your verified Gmail here
}

# 2. Lambda Function & ZIP
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda/janitor.py"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "janitor" {
  filename      = "lambda_function.zip"
  function_name = "CloudJanitor"
  role          = aws_iam_role.janitor_role.arn
  handler       = "janitor.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30

  environment {
    variables = { SNS_TOPIC_ARN = aws_sns_topic.janitor_alerts.arn }
  }
}

# 3. Scheduler (Runs every day at midnight)
resource "aws_cloudwatch_event_rule" "daily" {
  name                = "janitor-schedule"
  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "target" {
  rule = aws_cloudwatch_event_rule.daily.name
  arn  = aws_lambda_function.janitor.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.janitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}

resource "aws_iam_role" "janitor_role" {
  name = "cloud_janitor_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "janitor_policy" {
  role = aws_iam_role.janitor_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ec2:DescribeVolumes", "ec2:DeleteVolume", "ec2:DescribeSnapshots", "ec2:DeleteSnapshot", "sns:Publish"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}