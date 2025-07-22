variable "region" {
    description = "AWS region"
    type = string
}

variable "db_password" {
  description = "Password for the RDS PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "backend_s3_bucket_name" {
    description = "Backend S3 bucket name"
    type = string
}

variable "backend_s3_bucket_region" {
    description = "Backend S3 bucket region"
    type = string
}
