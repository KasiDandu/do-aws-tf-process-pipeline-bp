locals {
  lambda_enabled = var.lambda_settings != null
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  count              = local.lambda_enabled ? 1 : 0
  name               = "${local.prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  count      = local.lambda_enabled ? 1 : 0
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy" "lambda_glue" {
  count = local.lambda_enabled ? 1 : 0
  role  = aws_iam_role.lambda[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["glue:StartJobRun"]
      Resource = aws_glue_job.this.arn
    }]
  })
}

resource "aws_lambda_function" "this" {
  count         = local.lambda_enabled ? 1 : 0
  function_name = coalesce(var.lambda_settings.function_name, "${local.prefix}-trigger")
  role          = aws_iam_role.lambda[0].arn
  handler       = var.lambda_settings.handler
  runtime       = var.lambda_settings.runtime
  s3_bucket     = var.lambda_settings.s3_bucket
  s3_key        = var.lambda_settings.s3_key
  timeout       = var.lambda_settings.timeout
  memory_size   = var.lambda_settings.memory_size

  environment {
    variables = {
      GLUE_JOB_NAME = aws_glue_job.this.name
    }
  }
  tags = local.tags
}

resource "aws_lambda_event_source_mapping" "sqs" {
  count            = local.lambda_enabled ? 1 : 0
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = aws_lambda_function.this[0].arn
  batch_size       = 10
}
