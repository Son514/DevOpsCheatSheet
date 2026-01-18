# Configure the AWS provider and set the region where resources will be created
provider "aws" {
  region = "ap-southeast-2" # Sydney region
}

# Create an S3 bucket to store Terraform state files
resource "aws_s3_bucket" "terraform_state" {
  bucket = "chocoholic-terraform-centralized-state" # Unique bucket name

  force_destroy = true

  lifecycle {
    # Allow the bucket to be destroyed if needed (set to true to prevent accidental deletion)
    prevent_destroy = false
  }
}

# Enable versioning on the S3 bucket to keep history of state file changes
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption on the S3 bucket for security
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      # Use AES256 encryption for all objects stored in the bucket
      sse_algorithm = "AES256"
    }
  }
}

# Create a DynamoDB table to manage Terraform state locks
# This prevents multiple users from modifying the state at the same time
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "chocoholic-terraform-state-locks" # Unique table name
  billing_mode = "PAY_PER_REQUEST"                  # Pay only for what you use, no fixed capacity
  hash_key     = "LockID"                           # Primary key for the table

  attribute {
    name = "LockID"
    type = "S" # Attribute type is string
  }
}
