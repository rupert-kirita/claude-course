# LAB-11-AWS: Deploying Resources to Multiple Regions

## Overview
This lab demonstrates how to use multiple provider blocks in Terraform to deploy resources to different AWS regions simultaneously. You'll create resources in two regions using a simple, free configuration.

[![Lab 11](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml)

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
10 minutes

## Existing Configuration Files

The lab directory contains the following initial files that will be used for the lab:

 - `main.tf`
 - `variables.tf`
 - `providers.tf`

## Lab Steps

### 1. Initialize Terraform

Validate you are in the correct directory:

```bash
cd /workspaces/terraform-codespaces/labs/lab_11_using_multiple_providers_for_mulitple_regions/AWS
```

Initialize your Terraform workspace:
```bash
terraform init
```

### 2. Examine the Provider Configuration

Notice how the provider blocks are configured in providers.tf:
- The primary provider with an alias of `primary`
- The secondary provider with an alias of `secondary`

### 3. Examine the Resource Configuration

Look at how resources specify which provider to use:
- `provider = aws.primary` for resources in the primary region
- `provider = aws.secondary` for resources in the secondary region

> Note: Feel free to change the values of the variables `primary_region` and `secondary_region` to your local regions.

### 4. Run Plan and Apply

Create the resources in both regions:
```bash
terraform plan
terraform apply
```

> Feel free to browse the AWS Console (UI) to see that resources were deployed across two different regions. Specifically for Amazon S3, you don't need to change the region to see all of your buckets across different regions.

### 5. Add SNS Topics to Both Regions

Add the following resources to `main.tf`:

```hcl
# SNS Topic in primary region
resource "aws_sns_topic" "primary" {
  provider = aws.primary
  name     = "primary-${var.environment}-topic"

  tags = {
    Name        = "Primary Region Topic"
    Environment = var.environment
    Region      = var.primary_region
  }
}

# SNS Topic in secondary region
resource "aws_sns_topic" "secondary" {
  provider = aws.secondary
  name     = "secondary-${var.environment}-topic"

  tags = {
    Name        = "Secondary Region Topic"
    Environment = var.environment
    Region      = var.secondary_region
  }
}
```

### 6. Apply the Changes

Apply the configuration to create the SNS topics:
```bash
terraform apply
```

> Feel free to browse the AWS Console (UI) to see that resources were deployed across two different regions. For SNS topics, you'll need to change the region in the top right to see the resource in each respective region.


### 7. Create `outputs.tf` file to see information about the resources

Create an `outputs.tf` file:

```hcl
output "primary_bucket_name" {
  description = "Name of the S3 bucket in the primary region"
  value       = aws_s3_bucket.primary.bucket
}

output "secondary_bucket_name" {
  description = "Name of the S3 bucket in the secondary region"
  value       = aws_s3_bucket.secondary.bucket
}

output "primary_bucket_region" {
  description = "Region of the primary S3 bucket"
  value       = aws_s3_bucket.primary.region
}

output "secondary_bucket_region" {
  description = "Region of the secondary S3 bucket"
  value       = aws_s3_bucket.secondary.region
}

output "primary_sns_topic_arn" {
  description = "ARN of the SNS topic in the primary region"
  value       = aws_sns_topic.primary.arn
}

output "secondary_sns_topic_arn" {
  description = "ARN of the SNS topic in the secondary region"
  value       = aws_sns_topic.secondary.arn
}
```

### 8. Apply to See Outputs
```bash
terraform apply
```

Take a look at the outputs. Notice that the SNS topics are in two different regions (based on the ARN). That proves that the topics were deployed in two different regions but within the same Terraform configuration.

### 9. Clean Up Resources

When you are done, clean up all resources:

```bash
terraform destroy
```

## Understanding Multiple Provider Configuration

### Provider Aliases
- Provider aliases allow you to define multiple configurations for the same provider
- Each provider block can have its own configuration (region, credentials, etc.)
- Use the `alias` attribute to name each provider configuration

### Specifying Providers for Resources
- Use the `provider` attribute in resource blocks to specify which provider to use
- Format is `provider = aws.<alias>`
- If no provider is specified, the default provider (without an alias) is used

### Common Multi-Region Scenarios
- Disaster recovery across regions
- Deploying to multiple regions for reduced latency
- Creating resources that interact across regions

## Additional Exercises

1. Add a DynamoDB table to each region
2. Create a CloudWatch Log Group in each region
3. Create resources in a third region using an additional provider block