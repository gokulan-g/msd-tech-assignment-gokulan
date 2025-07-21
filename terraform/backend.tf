terraform {
  backend "s3" {
    bucket         = "msd-assignment-bucket"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true             # Enable encryption at rest
    dynamodb_table = "msd-assignment-table"
  }
}
