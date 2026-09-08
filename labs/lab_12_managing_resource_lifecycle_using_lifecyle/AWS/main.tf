# Random string for uniqueness
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket without lifecycle configuration
resource "aws_s3_bucket" "standard" {
  bucket = "standard-${var.environment}-${random_string.suffix.result}"

  tags = {
    Name        = "Standard Bucket"
    Environment = var.environment
  }
}

# DynamoDB Table without lifecycle configuration
resource "aws_dynamodb_table" "standard" {
  name         = "standard-${var.environment}-${random_string.suffix.result}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Id"

  attribute {
    name = "Id"
    type = "S"
  }

  tags = {
    Name        = "Standard Table"
    Environment = var.environment
  }
}