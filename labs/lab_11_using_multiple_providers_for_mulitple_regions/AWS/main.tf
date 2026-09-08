# S3 Bucket in primary region
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "primary-${var.environment}-${random_string.suffix.result}"

  tags = {
    Name        = "Primary Region Bucket"
    Environment = var.environment
    Region      = var.primary_region
  }
}

# S3 Bucket in secondary region
resource "aws_s3_bucket" "secondary" {
  provider = aws.secondary
  bucket   = "secondary-${var.environment}-${random_string.suffix.result}"

  tags = {
    Name        = "Secondary Region Bucket"
    Environment = var.environment
    Region      = var.secondary_region
  }
}

# Random string for bucket name uniqueness
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}