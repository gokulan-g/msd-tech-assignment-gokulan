variable "region" {
    description = "AWS region"
    default = "ap-south-1" #Mumbai region. Local to me
    type = string
}

variable "db_password" {
  description = "Password for the RDS PostgreSQL database"
  type        = string
  sensitive   = true
}
