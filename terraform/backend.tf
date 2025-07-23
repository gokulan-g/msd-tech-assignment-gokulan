terraform {
  # Configure remote backend to store Terraform state in S3
  backend "s3" {
    bucket         = ""  # Name of the S3 bucket to store the state file
    key            = ""  # Path to the state file within the bucket 
    region         = ""  # AWS region where the S3 bucket is located 
    encrypt        = ""  # Whether to encrypt the state file at rest
    dynamodb_table = ""  # DynamoDB table for state locking and consistency
  }
}
