# LAB-07-AWS: Simplifying Code with Local Values

## Overview
In this lab, you will learn how to use Terraform's `locals` blocks to refactor repetitive code, create computed values, and make your configurations more dynamic. You'll take an existing configuration with redundant elements and improve it by centralizing common values and creating more maintainable infrastructure code.

[![Lab 05](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

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

## Existing Configuration Files

The lab directory contains the following files with repetitive code that we'll refactor:

 - `main.tf`
 - `variables.tf`
 - `providers.tf`

Examine these files and notice:
- Repeated tag values across multiple resources
- Redundant naming patterns
- Hardcoded values that could be computed
- No centralized management of common elements

## Lab Steps

### 1. Configure AWS Credentials

Set up your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
```

### 2. Add Data Sources

Add the following data source to the top of `main.tf`:

```hcl
# Get information about the current region
data "aws_region" "current" {}
```

### 3. Create Locals Block

Add a locals block at the top of `main.tf` (after the data source):

```hcl
locals {
  # Common tags for all resources
  tags = {
    Environment = var.environment
    Project     = "terraform-demo"
    Owner       = "infrastructure-team"
    CostCenter  = "cc-1234"
    Region      = data.aws_region.current.name
    ManagedBy   = "terraform"
  }
  
  # Common name prefix for resources
  name_prefix = "${var.environment}-"
}
```

### 4. Refactor Resources

Replace the resources in `main.tf` with these refactored versions:

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${local.name_prefix}vpc-${data.aws_region.current.name}"  # <-- update value here
    Environment = local.tags.Environment  # <-- update value here
    Project     = local.tags.Project  # <-- update value here
    Owner       = local.tags.Owner  # <-- update value here
    CostCenter  = local.tags.CostCenter  # <-- update value here
    Region      = local.tags.Region  # <-- update value here
    ManagedBy   = local.tags.ManagedBy  # <-- update value here
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.name_prefix}public-subnet-us-east-1a"  # <-- update value here
    Environment = local.tags.Environment  # <-- update value here
    Project     = local.tags.Project  # <-- update value here
    Owner       = local.tags.Owner  # <-- update value here
    CostCenter  = local.tags.CostCenter  # <-- update value here
    Region      = local.tags.Region  # <-- update value here
    ManagedBy   = local.tags.ManagedBy  # <-- update value here
    Tier        = "public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.name_prefix}public-subnet-us-east-1b"  # <-- update value here
    Environment = local.tags.Environment  # <-- update value here
    Project     = local.tags.Project  # <-- update value here
    Owner       = local.tags.Owner  # <-- update value here
    CostCenter  = local.tags.CostCenter  # <-- update value here
    Region      = local.tags.Region  # <-- update value here
    ManagedBy   = local.tags.ManagedBy  # <-- update value here
    Tier        = "public"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name        = "${local.name_prefix}private-subnet-us-east-1a"  # <-- update value here
    Environment = local.tags.Environment  # <-- update value here
    Project     = local.tags.Project  # <-- update value here
    Owner       = local.tags.Owner  # <-- update value here
    CostCenter  = local.tags.CostCenter  # <-- update value here
    Region      = local.tags.Region  # <-- update value here
    ManagedBy   = local.tags.ManagedBy  # <-- update value here
    Tier        = "private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name        = "${local.name_prefix}private-subnet-us-east-1b"  # <-- update value here
    Environment = local.tags.Environment  # <-- update value here
    Project     = local.tags.Project  # <-- update value here
    Owner       = local.tags.Owner  # <-- update value here
    CostCenter  = local.tags.CostCenter  # <-- update value here
    Region      = local.tags.Region  # <-- update value here
    ManagedBy   = local.tags.ManagedBy  # <-- update value here
    Tier        = "private"
  }
}

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}web-sg"  # <-- update value here
  description = "Allow web traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}web-sg"  # <-- update value here
    Environment = local.tags.Environment  # <-- update value here
    Project     = local.tags.Project  # <-- update value here
    Owner       = local.tags.Owner  # <-- update value here
    CostCenter  = local.tags.CostCenter  # <-- update value here
    Region      = local.tags.Region  # <-- update value here
    ManagedBy   = local.tags.ManagedBy  # <-- update value here
  }
}
```

### 5. Create Outputs File

Create an `outputs.tf` file:

```hcl
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_a_id" {
  description = "The ID of public subnet in AZ a"
  value       = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  description = "The ID of public subnet in AZ b"
  value       = aws_subnet.public_b.id
}

output "private_subnet_a_id" {
  description = "The ID of private subnet in AZ a"
  value       = aws_subnet.private_a.id
}

output "private_subnet_b_id" {
  description = "The ID of private subnet in AZ b"
  value       = aws_subnet.private_b.id
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.web.id
}
```

### 6. Apply Initial Configuration

Initialize and apply the initial configuration:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Review the created resources in the AWS Console:
- Notice the consistent naming convention based on the environment variable
- Observe how all resources have the same tag values
- Check how names are formed using the name_prefix local value

### 7. Update Locals and Observe Changes

Now, let's demonstrate the power of centralized configuration by updating our locals block:

1. Modify the locals block in `main.tf` to update some values:

```hcl
locals {
  # Common tags for all resources
  tags = {
    Environment = var.environment
    Project     = "terraform-improved-demo"  # <-- Changed from "terraform-demo"
    Owner       = "devops-team"              # <-- Changed from "infrastructure-team"
    CostCenter  = "cc-5678"                  # <-- Changed from "cc-1234"
    Region      = data.aws_region.current.name
    ManagedBy   = "terraform"
  }
  
  # Common name prefix for resources
  name_prefix = "${var.environment}-tf-"     # <-- Added "tf-" to the prefix
}
```

2. Create a new `terraform.tfvars` file to change the environment:

```hcl
environment = "dev"
region      = "us-east-1"
vpc_cidr    = "10.0.0.0/16"
```

3. Apply the changes and observe the results:

```bash
terraform plan
terraform apply
```

4. Check the AWS Console again and notice:
   - All resources have been recreated or updated
   - All resource names now include "dev-tf-" instead of "production-"
   - All tags have been updated with the new project, owner, and cost center values
   - These changes were made by modifying only the locals block and tfvars file

This demonstrates how using locals allows you to make widespread changes to your infrastructure by modifying just a few values in a central location.

### 8. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Additional Exercises

1. Add more computed values to the locals block
2. Create local variables for the CIDR blocks instead of hardcoding them
3. Define the availability zones in the locals block
4. Experiment with different environment values in terraform.tfvars