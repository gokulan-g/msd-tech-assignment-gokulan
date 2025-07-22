variable "region" {
    description = "AWS region"
    type = string
}

variable "db_password" {
  description = "Password for the RDS PostgreSQL database"
  type        = string
  sensitive   = true
}
