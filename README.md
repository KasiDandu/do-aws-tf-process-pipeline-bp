# do-aws-tf-process-pipeline-bp

Versioned Terraform blueprint for a **process**-type data pipeline. Called from
`do-aws-pipeline-infra/{env}/{pipeline}/process/main.tf`:

```hcl
module "pipeline" {
  source = "git::https://github.com/KasiDandu/do-aws-tf-process-pipeline-bp.git?ref=v0.0.1"
  # ...
}
```

Creates, per environment and pipeline:

- S3 buckets for the `bronze` and `silver` lakehouse layers
- an SQS queue with a dead-letter queue
- a Glue catalog database, Glue job and IAM role
- optionally (when `lambda_settings` is set) a Lambda that starts the Glue job from SQS messages

| Input | Purpose |
|---|---|
| `environment`, `data_pipeline` | Naming: `{environment}-{data_pipeline}-...` |
| `glue_job_settings` | Script location, extra py files, workers, timeout, extra arguments |
| `lambda_settings` | Optional Lambda package (S3 bucket/key), handler, runtime |
| `queue_settings` | Visibility timeout and max receive count before the DLQ |
| `s3_settings` | `force_destroy` for practice environments |

Release with a new tag (`v0.0.2`, ...). Never move an existing tag.
