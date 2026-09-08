# LAB-16-AWS: Replacing and Removing Resources in Terraform

## Overview
In this lab, you will learn how to replace and remove resources in Terraform. You'll practice using the `-replace` flag and removing resources from configuration using free AWS resources.

[![Lab 16](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml)

## Prerequisites
- Terraform installed
- AWS free tier account
- Basic understanding of Terraform and AWS concepts

Note: AWS credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each **lab** to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time
30 minutes

## Initial Configuration Files

Create the following files in your working directory:

### variables.tf
```hcl
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "tf-lab16"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "dev"
}

variable "lab_name" {
  description = "Lab identifier for tagging"
  type        = string
  default     = "lab16"
}

variable "random_suffix_length" {
  description = "Length of random suffix for unique resource names"
  type        = number
  default     = 8
}

variable "assume_role_service" {
  description = "Service that can assume the IAM role"
  type        = string
  default     = "s3.amazonaws.com"
}

variable "policy_actions" {
  description = "List of actions to allow in the IAM policy"
  type        = list(string)
  default     = ["s3:ListBucket"]
}

variable "bucket_tag_name" {
  description = "Name tag for the bucket"
  type        = string
  default     = "example-bucket"
}

variable "effect_type" {
  description = "Effect type for IAM policies"
  type        = string
  default     = "Allow"
}

variable "policy_description" {
  description = "Description for the IAM policy"
  type        = string
  default     = "Example policy for lab exercises"
}

variable "special_chars_allowed" {
  description = "Allow special characters in random string"
  type        = bool
  default     = false
}

variable "upper_chars_allowed" {
  description = "Allow uppercase characters in random string"
  type        = bool
  default     = false
}
```

### main.tf
```hcl
# S3 Bucket
resource "aws_s3_bucket" "example" {
  bucket = "${var.prefix}-example-${random_string.suffix.result}"

  tags = {
    Name        = var.bucket_tag_name
    Environment = var.environment
    Lab         = var.lab_name
  }
}

# IAM Role
resource "aws_iam_role" "example" {
  name = "${var.prefix}-example-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = var.effect_type
        Principal = {
          Service = var.assume_role_service
        }
      }
    ]
  })

  tags = {
    Lab = var.lab_name
    Environment = var.environment
  }
}

# IAM Policy
resource "aws_iam_policy" "example" {
  name        = "${var.prefix}-example-policy"
  description = "${var.policy_description} for ${var.lab_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = var.policy_actions
        Effect   = var.effect_type
        Resource = aws_s3_bucket.example.arn
      }
    ]
  })
}

# Policy Attachment
resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.example.name
  policy_arn = aws_iam_policy.example.arn
}

# Random string for bucket name uniqueness
resource "random_string" "suffix" {
  length  = var.random_suffix_length
  special = var.special_chars_allowed
  upper   = var.upper_chars_allowed
}
```

### providers.tf
```hcl
terraform {
  required_version = ">= 1.12.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

### outputs.tf
```hcl
output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.example.bucket
}

output "role_name" {
  description = "Name of the created IAM role"
  value       = aws_iam_role.example.name
}

output "policy_name" {
  description = "Name of the created IAM policy"
  value       = aws_iam_policy.example.name
}
```

## Lab Steps

### 1. Initialize and Apply
```bash
terraform init
terraform apply -auto-approve
```

### 2. Replace a Resource Using the `-replace` Flag

Let's replace the IAM role without changing its configuration:

```bash
terraform apply -replace="aws_iam_role.example" -auto-approve
```

Observe in the output how Terraform:
- Destroys the existing role
- Creates a new role with the same configuration

### 3. Replace a Resource by Modifying Configuration

Let's update the variables to change the bucket's configuration. Create a file called `modified.tfvars`:

```hcl
prefix = "tf-lab16-mod"
bucket_tag_name = "modified-bucket"
environment = "test"
```

Apply with the new variables:

```bash
terraform apply -var-file="modified.tfvars" -auto-approve
```

Observe how Terraform plans to replace the bucket due to the name change.

### 4. Remove a Resource by Deleting it from Configuration

Remove or comment out the IAM policy attachment resource from main.tf:

```hcl
# Policy Attachment
# resource "aws_iam_role_policy_attachment" "example" {
#   role       = aws_iam_role.example.name
#   policy_arn = aws_iam_policy.example.arn
# }
```

Apply the changes:

```bash
terraform apply
```

Observe that Terraform plans to destroy the policy attachment since we "removed" it from our `main.tf` file and it is no longer part of our desired configuration.

### 5. Remove a Resource Using `terraform destroy -target`

Now, let's remove the IAM policy using targeted destroy without changing the configuration:

```bash
terraform destroy -target=aws_iam_policy.example
```

Notice that Terraform will destroy the IAM policy since we targeted that specific resource on a `terraform destroy` command. Type in `yes` to confirm and destroy the resource.

Verify it's gone:

```bash
terraform state list
```

Run a normal apply to recreate it - this is because we did NOT remove it from our desired configuration (`main.tf`) and Terraform compared the real-world resources to our desired configuration and, as a result, created the IAM policy again.

```bash
terraform apply
```

### 6. Clean Up

When finished, clean up all resources and remove them from your account:

```bash
terraform destroy -auto-approve
```

## Key Concepts

### Resource Replacement Methods
- **Using `-replace` flag**: Forces resource recreation without configuration changes
- **Changing force-new attributes**: Some attribute changes automatically trigger replacement

### Resource Removal Methods
- **Removing from configuration**: Delete the resource block from your .tf files
- **Using `terraform destroy -target`**: Temporarily removes a resource; it will be recreated on next apply

## Additional Challenge

1. Create a terraform.tfvars file that changes multiple variables at once, then observe which resources get replaced
2. Try using `-replace` with a resource that has dependencies and observe how Terraform handles the dependencies