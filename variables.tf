variable "environment" {
  type = string
}

variable "data_pipeline" {
  type = string
}

variable "glue_job_settings" {
  type = object({
    job_name          = optional(string)
    script_location   = string
    extra_py_files    = optional(string)
    glue_version      = optional(string, "4.0")
    worker_type       = optional(string, "G.1X")
    number_of_workers = optional(number, 2)
    timeout           = optional(number, 30)
    default_arguments = optional(map(string), {})
  })
}

variable "lambda_settings" {
  type = object({
    function_name = optional(string)
    handler       = optional(string, "handler.lambda_handler")
    runtime       = optional(string, "python3.12")
    s3_bucket     = string
    s3_key        = string
    timeout       = optional(number, 60)
    memory_size   = optional(number, 256)
  })
  default = null
}

variable "queue_settings" {
  type = object({
    visibility_timeout_seconds = optional(number, 120)
    max_receive_count          = optional(number, 3)
  })
  default = {}
}

variable "s3_settings" {
  type = object({
    force_destroy = optional(bool, false)
  })
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
