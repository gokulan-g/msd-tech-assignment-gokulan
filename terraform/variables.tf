variable "region" {
    description = "AWS region"
    type = string
}

variable "db_password" {
  description = "Password for the RDS PostgreSQL database"
  type        = string
  sensitive   = true
}

variable "application_load_balancer_name" {
    description = "Application Load Balancer"
    type = string
}

variable "application_load_balancer_region" {
    description = "Application Load Balancer Region"
    type = string
}
