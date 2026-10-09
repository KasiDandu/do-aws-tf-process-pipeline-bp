output "glue_job_name" {
  value = aws_glue_job.this.name
}

output "queue_url" {
  value = aws_sqs_queue.main.url
}

output "bronze_bucket" {
  value = aws_s3_bucket.layer["bronze"].bucket
}

output "silver_bucket" {
  value = aws_s3_bucket.layer["silver"].bucket
}

output "lambda_function_name" {
  value = local.lambda_enabled ? aws_lambda_function.this[0].function_name : null
}
