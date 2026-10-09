data "aws_caller_identity" "current" {}

locals {
  prefix        = "${var.environment}-${var.data_pipeline}"
  account_id    = data.aws_caller_identity.current.account_id
  script_bucket = split("/", trimprefix(var.glue_job_settings.script_location, "s3://"))[0]
  tags = merge(var.tags, {
    environment   = var.environment
    data_pipeline = var.data_pipeline
    managed_by    = "terraform"
  })
}

# ---------- lakehouse layers ----------
resource "aws_s3_bucket" "layer" {
  for_each      = toset(["bronze", "silver"])
  bucket        = "${local.prefix}-${each.key}-${local.account_id}"
  force_destroy = var.s3_settings.force_destroy
  tags          = local.tags
}

# ---------- queue + dead-letter queue ----------
resource "aws_sqs_queue" "dlq" {
  name = "${local.prefix}-dlq"
  tags = local.tags
}

resource "aws_sqs_queue" "main" {
  name                       = "${local.prefix}-queue"
  visibility_timeout_seconds = var.queue_settings.visibility_timeout_seconds
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.queue_settings.max_receive_count
  })
  tags = local.tags
}

# ---------- Glue ----------
resource "aws_glue_catalog_database" "this" {
  name = replace("${local.prefix}_db", "-", "_")
}

data "aws_iam_policy_document" "glue_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue" {
  name               = "${local.prefix}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "glue_s3" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = flatten([for b in aws_s3_bucket.layer : [b.arn, "${b.arn}/*"]])
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.script_bucket}/*"]
  }
}

resource "aws_iam_role_policy" "glue_s3" {
  role   = aws_iam_role.glue.id
  policy = data.aws_iam_policy_document.glue_s3.json
}

resource "aws_glue_job" "this" {
  name              = coalesce(var.glue_job_settings.job_name, "${local.prefix}-glue-job")
  role_arn          = aws_iam_role.glue.arn
  glue_version      = var.glue_job_settings.glue_version
  worker_type       = var.glue_job_settings.worker_type
  number_of_workers = var.glue_job_settings.number_of_workers
  timeout           = var.glue_job_settings.timeout

  command {
    name            = "glueetl"
    script_location = var.glue_job_settings.script_location
    python_version  = "3"
  }

  default_arguments = merge(
    {
      "--job-language"  = "python"
      "--SOURCE_BUCKET" = aws_s3_bucket.layer["bronze"].bucket
      "--TARGET_BUCKET" = aws_s3_bucket.layer["silver"].bucket
      "--DATABASE"      = aws_glue_catalog_database.this.name
    },
    var.glue_job_settings.extra_py_files == null ? {} : {
      "--extra-py-files" = var.glue_job_settings.extra_py_files
    },
    var.glue_job_settings.default_arguments,
  )

  tags = local.tags
}
