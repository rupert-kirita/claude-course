# LAB-19-AWS: Importing an Existing Resource

## Overview

In this lab, you will bring existing, unmanaged AWS resources under Terraform management using both the `terraform import` CLI command and the `import` block. You'll start with live infrastructure and an **empty state file**, import each resource, and prove the configuration matches with a clean plan.

This lab picks up exactly where [Lab 18](../../lab_18_refactor_state_with_moved_and_removed_blocks/AWS/aws.md) left off: the VPC, subnet, and security group you orphaned with `removed` blocks still exist in AWS, but Terraform no longer knows about them. By the end of this lab they are back under Terraform management — and a final `terraform destroy` cleans up everything Lab 18 left behind.

[![Lab 19](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml)

## Prerequisites

- Terraform installed (v1.12.2+)
- AWS free tier account
- The orphaned resources from Lab 18 (`lab-vpc`, `lab-subnet`, `lab-web-sg`) still in place — see the note in Step 1 if you skipped Lab 18
- Basic understanding of Terraform and AWS concepts

Note: AWS credentials are required for this lab. Export them — along with a default region for the AWS CLI commands used in Step 1 — before you begin:

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="us-east-1"
```

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).
2. Once the Codespace is running, open the integrated terminal.
3. Change into this lab's directory: `cd labs/lab_19_import_a_resource/AWS`
4. Follow the instructions below to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time

30 minutes

## Initial Configuration Files

This lab ships with three starter files in the working directory: `providers.tf`, `variables.tf`, and `main.tf`. Unlike previous labs, `main.tf` starts out empty — the resources already exist in AWS, and your job is to write the configuration that matches them.

### providers.tf

```hcl
terraform {
  required_version = ">= 1.12.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

### variables.tf

```hcl
variable "aws_region" {
  description = "AWS region where the Lab 18 resources live"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "lab"
}

variable "environment" {
  description = "Environment name for tagging (must match the existing resources)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block of the existing VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block of the existing subnet"
  type        = string
  default     = "10.0.1.0/24"
}
```

### main.tf

```hcl
# This file starts intentionally empty.
#
# The VPC, subnet, and security group created in Lab 18 still exist in
# AWS, but they are no longer tracked in Terraform state. During this
# lab you will add resource and import blocks here to bring each one
# back under Terraform management.
```

## Lab Steps

### 1. Confirm the Orphaned Resources Still Exist

Lab 18 ended with `removed` blocks that took the VPC, subnet, and security group out of Terraform state while leaving them running in AWS.

You need the IDs of all three resources to import them. If you recorded the IDs in Lab 18 Step 8, you can use those. You can find the same IDs in the AWS console under **VPC → Your VPCs**, **VPC → Subnets**, and **EC2 → Security Groups**.

> **Skipped Lab 18?** Create the three resources manually in the AWS console first: a VPC named `lab-vpc` with CIDR `10.0.0.0/16`, a subnet named `lab-subnet` with CIDR `10.0.1.0/24` inside that VPC, and a security group named `lab-web-sg` with the description `Lab security group` in the same VPC. Tag all three resources with `Environment = dev`, and add a `Name` tag to the security group matching its name (the console does not create one for you like it does for the VPC and subnet). Then continue from here.

### 2. Initialize and Confirm the State Is Empty

Initialize the working directory, then list the resources Terraform is managing:

```bash
terraform init
terraform state list
```

The `terraform state list` command returns nothing. Real infrastructure exists, but the state file knows about none of it.

### 3. Write a Resource Block for the VPC

Start with the `terraform import` CLI command. As a reminder, it does not write configuration for you, and it refuses to run until a resource block for the target address exists — so the resource block comes first.

Add the following resource block to `main.tf`, describing the VPC exactly as it exists in AWS:

```hcl
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "${var.prefix}-vpc"
    Environment = var.environment
  }
}
```

> The address does not need to match the one Lab 18 used. What must match is the real resource's attributes, like the CIDR block and all three tags.

### 4. Import the VPC with the `terraform import` Command

Run the import command, substituting the VPC ID you gathered in Step 1:

```bash
terraform import aws_vpc.main vpc-xxxxxxxxxxxxxxxxx
```

You should see output similar to:

```
aws_vpc.main: Importing from ID "vpc-xxxxxxxxxxxxxxxxx"...
aws_vpc.main: Import prepared!
  Prepared aws_vpc for import
aws_vpc.main: Refreshing state... [id=vpc-xxxxxxxxxxxxxxxxx]

Import successful!

The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.
```

Confirm the VPC is back in state:

```bash
terraform state list
```

You should see exactly one address:

```
aws_vpc.main
```

### 5. Verify the Configuration Matches Reality

Run a plan:

```bash
terraform plan
```

You should see:

```
No changes. Your infrastructure matches the configuration.
```

A clean plan is the proof the import worked.

> If the plan shows changes, your configuration does not match the real resource. Fix the **configuration**, not the infrastructure, and plan again until it is clean.

### 6. Import the Subnet with an `import` Block

Next, use the `import` block. Instead of running a command per resource, you declare the import in configuration and let a single apply handle several imports at once.

Add the following to `main.tf`, substituting your subnet ID from Step 1:

```hcl
import {
  to = aws_subnet.app
  id = "subnet-xxxxxxxxxxxxxxxxx"
}

resource "aws_subnet" "app" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidr

  tags = {
    Name        = "${var.prefix}-subnet"
    Environment = var.environment
  }
}
```

Run a plan:

```bash
terraform plan
```

The plan now includes an import operation:

```
Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
```

Nothing has happened yet, because import blocks perform the import at **apply** time. Don't apply yet — first, add the security group so a single apply imports both resources.

### 7. Generate the Security Group Configuration Automatically

For the subnet, you hand-wrote the resource block. For the security group, let Terraform write it for you. Add **only** an import block to `main.tf` — no resource block this time — substituting your security group ID from Step 1:

```hcl
import {
  to = aws_security_group.main
  id = "sg-xxxxxxxxxxxxxxxxx"
}
```

Now generate configuration for any import target that has no matching resource block:

```bash
terraform plan -generate-config-out=generated.tf
```

Open `generated.tf` and review it. Every value is a hardcoded literal (the `vpc_id` is a raw `"vpc-..."` string instead of a reference to `aws_vpc.main.id`), and every settable attribute is listed. Move the resource block into `main.tf` and clean it up so it looks like this:

```hcl
resource "aws_security_group" "main" {
  name        = "${var.prefix}-web-sg"
  description = "Lab security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.prefix}-web-sg"
    Environment = var.environment
  }
}
```

Delete the now-empty `generated.tf` file, then run a plan to confirm both pending imports are recognized:

```bash
terraform plan
```

```
Plan: 2 to import, 0 to add, 0 to change, 0 to destroy.
```

### 8. Apply to Complete the Imports

Run the apply:

```bash
terraform apply -auto-approve
```

Terraform imports both resources in one operation:

```
Apply complete! Resources: 2 imported, 0 added, 0 changed, 0 destroyed.
```

### 9. Verify Everything Is Under Management

List the state one more time:

```bash
terraform state list
```

You should see all three resources:

```
aws_security_group.main
aws_subnet.app
aws_vpc.main
```

Run a final plan and confirm it comes back clean:

```bash
terraform plan
```

```
No changes. Your infrastructure matches the configuration.
```

Finally, **delete the two `import` blocks** from `main.tf`. Like `moved` and `removed` blocks, they describe a one-time operation and can be removed once applied.

## Clean Up

Now that Terraform manages the resources again, `terraform destroy` works.

Destroy the infrastructure:

```bash
terraform destroy -auto-approve
```

You should see:

```
Destroy complete! Resources: 3 destroyed.
```

This removes the resources Lab 18 intentionally left behind.

## Key Concepts

### Importing Changes State, Never Infrastructure

- Both methods bind a resource address to a real object — the object itself is untouched.
- Terraform does not reconcile your configuration on import; it simply starts comparing the two. A clean plan is the proof the import worked.

### Two Methods, One Goal

| | `terraform import` (CLI) | `import` block (config-driven) |
| --- | --- | --- |
| Style | Imperative, one command per resource | Declarative, lives in your configuration |
| Configuration | You must hand-write the resource block first | Optional generation via `-generate-config-out` |
| Scale | One resource at a time | Many resources in a single apply |
| Reviewability | Runs from your terminal, leaves no trace in the repo | Visible in version control and code review |

### Generated Configuration Needs Cleanup

- `-generate-config-out` hardcodes every value as a literal and includes every settable attribute — treat it as a draft: replace literals with references and variables, prune, and review before applying.
- Like `moved` and `removed` blocks, `import` blocks describe a one-time operation and can be deleted once applied.

## Additional Challenge

1. Recreate the `outputs.tf` file from Lab 18 Step 8 (VPC ID, subnet ID, security group ID) and confirm the output values match the IDs you imported — proof that these are the very same resources.
2. Introduce deliberate drift before the final destroy: change the subnet's `Name` tag in your configuration to a different value, run `terraform plan`, and observe how Terraform proposes an in-place update. Revert the change and confirm the plan is clean again.
3. Inspect an imported resource in detail with `terraform state show aws_vpc.main` and compare each attribute against your resource block. How many attributes does the state track that your configuration never mentions?
