# LAB-18-AWS: Refactoring State with the `moved` and `removed` Blocks

## Overview

In this lab, you will refactor your Terraform configuration **without destroying and recreating live infrastructure**. You'll build a small set of AWS networking resources, then see firsthand what happens when you rename a resource *without* a `moved` block. You'll fix the rename properly with a `moved` block, practice moving a resource into and back out of a child module, and then use `removed` blocks in both of their modes: first to destroy a resource you no longer need, and then to hand ownership of the remaining resources off so they stay in place while Terraform stops managing them.

The resources you orphan at the end of this lab are intentionally left in place so they can be imported back under Terraform management in a future lab. Delete them yourself when you're done (see [Clean Up](#clean-up)).

[![Lab 18](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml)

## Prerequisites

- Terraform installed (v1.12.2+)
- AWS free tier account
- Basic understanding of Terraform and AWS concepts

Note: AWS credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions below to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time

40 minutes

## Initial Configuration Files

This lab ships with three starter files in the working directory: `providers.tf`, `variables.tf`, and `main.tf`. You will create an `outputs.tf` file later, in Step 8.

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
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "lab"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}
```

### main.tf

```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "${var.prefix}-vpc"
    Environment = var.environment
  }
}

# Subnet
resource "aws_subnet" "app" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidr

  tags = {
    Name        = "${var.prefix}-subnet"
    Environment = var.environment
  }
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.prefix}-rt"
    Environment = var.environment
  }
}

# Security Group
resource "aws_security_group" "web" {
  name        = "${var.prefix}-web-sg"
  description = "Lab security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.prefix}-web-sg"
    Environment = var.environment
  }
}
```

## Lab Steps

### 1. Review and Deploy the Starting Configuration

Initialize the working directory, review the plan, then apply to create the four resources:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

Terraform creates the VPC, subnet, route table, and security group.

### 2. Confirm the Resources Are Tracked in State

List the resources Terraform is managing:

```bash
terraform state list
```

You should see the following four addresses:

```
aws_route_table.main
aws_security_group.web
aws_subnet.app
aws_vpc.main
```

### 3. See What a Rename Does WITHOUT a `moved` Block

Suppose you want to rename the security group resource from `web` to `app` to better reflect its purpose. Before reaching for a `moved` block, see how Terraform interprets a plain rename.

In `main.tf`, change the security group resource label from `web` to `app`. Leave the `name` argument set to `"${var.prefix}-web-sg"`:

```hcl
resource "aws_security_group" "app" {
  name        = "${var.prefix}-web-sg"
  description = "Lab security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.prefix}-web-sg"
    Environment = var.environment
  }
}
```

Run a plan, but **DO NOT apply**:

```bash
terraform plan
```

Look closely at the output. Terraform has no idea these are the same resource. It sees `aws_security_group.web` vanish from the configuration and a brand-new `aws_security_group.app` appear, so it plans to destroy one and create the other:

```
Plan: 1 to add, 0 to change, 1 to destroy.
```

On a production system this means downtime. In this specific case the apply could even fail partway through, because a security group name must be unique within a VPC, and the new group uses the same name as the group Terraform is destroying.

> Do not apply this plan. In the next step you'll tell Terraform what you actually meant.

### 4. Rename the Resource Properly with a `moved` Block

A `moved` block tells Terraform that the resource at a new address is the *same object* as the one at the old address, so it updates the state entry instead of destroying and recreating the resource.

Leave the renamed resource block in place and add the following `moved` block to `main.tf`:

```hcl
moved {
  from = aws_security_group.web
  to   = aws_security_group.app
}
```

Run a plan and confirm Terraform now reports a move with zero resources to add, change, or destroy:

```bash
terraform plan
```

You should see a line similar to:

```
aws_security_group.web has moved to aws_security_group.app
```

Apply the change, then confirm the resource now appears under its new address:

```bash
terraform apply -auto-approve
terraform state list
```

Once the move is applied, **delete the `moved` block** from `main.tf`. That's safe here because you're the only user of this configuration and you've already applied the move. In a shared module, you'd keep the `moved` block in place so other users get the same upgrade path.

### 5. Move the Subnet Into a Child Module

Renames aren't the only refactor a `moved` block can handle — it can also relocate a resource into a module. Suppose your team decides all networking resources should live in a reusable module.

Create the module directory:

```bash
mkdir -p modules/network
```

Create a new file at `modules/network/main.tf` with the following content:

```hcl
variable "vpc_id" {
  description = "ID of the VPC where the subnet will be created"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "lab_name" {
  description = "Lab identifier for tagging"
  type        = string
}

resource "aws_subnet" "app" {
  vpc_id     = var.vpc_id
  cidr_block = var.subnet_cidr

  tags = {
    Name        = "${var.prefix}-subnet"
    Environment = var.environment
  }
}
```

In `main.tf`, delete the `aws_subnet.app` resource block and replace it with a module block and a `moved` block:

```hcl
module "network" {
  source = "./modules/network"

  vpc_id      = aws_vpc.main.id
  subnet_cidr = var.subnet_cidr
  prefix      = var.prefix
  environment = var.environment
}

moved {
  from = aws_subnet.app
  to   = module.network.aws_subnet.app
}
```

Because you added a new module, initialize the working directory again so Terraform installs it:

```bash
terraform init
```

Run a plan and confirm Terraform reports a move with zero resources to add, change, or destroy:

```bash
terraform plan
```

You should see a line similar to:

```
aws_subnet.app has moved to module.network.aws_subnet.app
```

Apply the change, then confirm the subnet now lives at a module address:

```bash
terraform apply -auto-approve
terraform state list
```

The subnet appears as `module.network.aws_subnet.app`. The real subnet in AWS was never touched.

### 6. Move the Subnet Back to the Root Module

Moves work in both directions. A future import lab expects these resources in a flat configuration, so move the subnet back to the root module before the handoff.

First, delete the `moved` block you added in Step 5 — it has been applied and has served its purpose.

In `main.tf`, delete the `module "network"` block and restore the original subnet resource block:

```hcl
resource "aws_subnet" "app" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.subnet_cidr

  tags = {
    Name        = "${var.prefix}-subnet"
    Environment = var.environment
  }
}
```

Add a `moved` block pointing in the opposite direction:

```hcl
moved {
  from = module.network.aws_subnet.app
  to   = aws_subnet.app
}
```

Run a plan, confirm the move with zero changes, and apply:

```bash
terraform plan
terraform apply -auto-approve
terraform state list
```

Delete this `moved` block as well, and remove the now-unused module directory:

```bash
rm -r modules
```

### 7. Destroy the Route Table with a `removed` Block

A `removed` block tells Terraform to stop managing a resource. It has two modes, and this step demonstrates the default one: remove the resource from state **AND** destroy the real infrastructure.

Your configuration no longer needs the route table, so retire it the configuration-driven way. In `main.tf`, delete the `aws_route_table.main` resource block and add the following `removed` block in its place:

```hcl
removed {
  from = aws_route_table.main

  lifecycle {
    destroy = true
  }
}
```

The `destroy` argument is set to `true` here for clarity, but `true` is the default. Run a plan and note the difference from every plan so far in this lab — this one destroys real infrastructure:

```bash
terraform plan
```

You should see:

```
Plan: 0 to add, 0 to change, 1 to destroy.
```

Apply the change, then confirm the route table is gone from state:

```bash
terraform apply -auto-approve
terraform state list
```

You should see only three addresses remaining. If you check the AWS console, the route table has been deleted. Keep this result in mind — in Step 9 you'll use the same block type with one argument flipped to get the opposite behavior.

Once the apply completes, **delete the `removed` block** from `main.tf`.

### 8. Add Output Blocks to Retrieve the Resource IDs

Before you orphan the remaining resources, capture their IDs. You'll need them to import these resources back in a future lab.

Create a new `outputs.tf` file with the following content:

```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = aws_subnet.app.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.app.id
}
```

Run a plan and apply to render the outputs:

```bash
terraform plan
terraform apply -auto-approve
```

In the terminal you'll see the output values (for example `vpc-0abc...`, `subnet-0def...`, `sg-0ghi...`). **Write these three IDs down somewhere safe** — a future import lab uses them as the import identifiers.

### 9. Orphan the Remaining Resources with `removed` Blocks

In Step 7, a `removed` block destroyed the route table. Setting the `lifecycle` `destroy` argument to `false` changes the behavior entirely: Terraform forgets the resource but leaves it untouched in AWS.

Delete all three resource blocks from `main.tf`. Also **delete the `outputs.tf` file**, because its outputs reference the resources you're about to remove and would cause an error once those resources leave the configuration. You already recorded the IDs in Step 8.

Add the following three `removed` blocks to `main.tf` in place of the deleted resource blocks:

```hcl
removed {
  from = aws_vpc.main

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_subnet.app

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_security_group.app

  lifecycle {
    destroy = false
  }
}
```

Run a plan and confirm Terraform reports the resources will be removed from state with zero resources to destroy:

```bash
terraform plan
```

Compare this against the plan from Step 7. Same block type, but with `destroy = false` the plan shows nothing being destroyed.

Apply the change:

```bash
terraform apply -auto-approve
```

### 10. Verify State Is Empty and the Resources Still Exist

Confirm Terraform is no longer managing anything:

```bash
terraform state list
```

This command should return no results.

Use the AWS console to confirm the resources still exist: open the VPC console and confirm the VPC, its subnet, and the security group are all still present. They exist, but they're no longer under Terraform management — ready to be imported in a future lab.

## Clean Up

> `terraform destroy` will **not** remove these resources, because your state file is now empty. The route table was already destroyed by Terraform in Step 7, so only the VPC and its contents remain.

Delete the remaining resources in the AWS console (VPC console → select the VPC → **Delete VPC**). Deleting the VPC removes the subnet and security group along with it.

## Key Concepts

### The `moved` Block

- Records a change of address for a resource inside Terraform state.
- Lets you rename a resource, or move it into or out of a module, without Terraform interpreting the change as a destroy-and-recreate. **The real infrastructure is never touched.**
- Deleting a `moved` block after it's applied is safe for a private configuration, but is a breaking change for a shared module — consumers who haven't yet applied the move would see a destroy plan instead.

### The `removed` Block

- The configuration-driven replacement for the older `terraform state rm` command.
- Its behavior hinges on the `lifecycle` `destroy` argument:
  - **`destroy = true`** (the default) — removes the resource from state **and** destroys the real object.
  - **`destroy = false`** — Terraform forgets the resource but leaves the real object in place. This is how you hand a resource off between configurations, split a large state file, or transfer ownership between teams without downtime.

## Additional Challenge

1. Move *all* of the networking resources into the child module in a single refactor (not just the subnet), using one `moved` block per resource.
2. After orphaning the resources, run `terraform import` to bring the VPC back under management using the ID you captured in Step 8.
3. Add a second `moved` block that renames a resource *and* moves it into a module in the same apply, and confirm Terraform still reports zero changes.
