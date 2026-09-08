# LAB-20-AWS: Migrating State to a Remote S3 Backend with State Locking

## Overview

In this lab, you will migrate Terraform state from the local backend to a remote S3 backend with native state locking enabled. You will inspect the local state file, provision a state bucket, migrate state with `terraform init -migrate-state`, strand and repair a state lock with `terraform force-unlock`, and migrate state back to local before cleaning up.

[![Lab 20](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml)

## Prerequisites

- Terraform installed (v1.12.2+)
- AWS free tier account
- Basic understanding of Terraform and AWS concepts

Note: AWS credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).
2. Once the Codespace is running, open the integrated terminal.
3. Change into this lab's directory: `cd labs/lab_20_migrate_state_to_a_new_backend/AWS`
4. Follow the instructions below to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time

30 minutes

## Initial Configuration Files

This lab ships with three starter files in the working directory — `providers.tf`, `variables.tf`, and `main.tf` — plus an `s3_backend` subdirectory. The `s3_backend` directory is a small bootstrap configuration that creates the state bucket and keeps its own local state, since the bucket has to exist before the backend that uses it can be initialized.

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

# Security Group
resource "aws_security_group" "app" {
  name        = "${var.prefix}-app-sg"
  description = "Lab security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.prefix}-app-sg"
    Environment = var.environment
  }
}
```

### s3_backend/main.tf

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
  region = "us-east-1"
}

# Used to build a globally unique bucket name
data "aws_caller_identity" "current" {}

# Bucket that will store the Terraform state file
resource "aws_s3_bucket" "state" {
  bucket = "lab-tf-state-${data.aws_caller_identity.current.account_id}"

  # Allows terraform destroy to remove the bucket even when it
  # still contains state files and old object versions
  force_destroy = true

  tags = {
    Name    = "lab-tf-state"
    Purpose = "terraform-remote-state"
  }
}

# Keep old versions of the state file so it can be recovered
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state"
  value       = aws_s3_bucket.state.bucket
}
```

## Lab Steps

### 1. Deploy the Starting Configuration on the Local Backend

There is no `backend` block in `providers.tf`, so Terraform uses the local backend and stores state in a `terraform.tfstate` file in the working directory.

Initialize and deploy the three networking resources:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

### 2. Inspect the Local State File

Confirm the state file exists on local disk:

```bash
ls -l terraform.tfstate
```

List the resources Terraform recorded in it:

```bash
terraform state list
```

```
aws_security_group.app
aws_subnet.app
aws_vpc.main
```

### 3. Provision the S3 State Bucket

Move into the bootstrap directory:

```bash
cd s3_backend
```

Review `main.tf`. The bucket name ends in your AWS account ID for global uniqueness, `force_destroy = true` allows the bucket to be destroyed while it still holds objects, and versioning keeps every version of the state file.

Deploy the bucket:

```bash
terraform init
terraform apply -auto-approve
```

```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

state_bucket_name = "lab-tf-state-123456789012"
```

Record the `state_bucket_name` value, then return to the working directory:

```bash
cd ..
```

### 4. Add the backend Block

In `providers.tf`, add a `backend "s3"` block inside the `terraform` block, replacing `<YOUR_STATE_BUCKET_NAME>` with the bucket name you recorded in Step 3:

```hcl
terraform {
  required_version = ">= 1.12.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "<YOUR_STATE_BUCKET_NAME>"
    key          = "networking/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

Backend blocks cannot use variables, so the bucket name must be a literal string.

Run a plan **without** re-initializing:

```bash
terraform plan
```

```
Error: Backend initialization required, please run "terraform init"

Reason: Initial configuration of the requested backend "s3"
```

Any change to the backend configuration requires running `terraform init` again.

### 5. Migrate State to S3

Re-initialize with the `-migrate-state` flag:

```bash
terraform init -migrate-state
```

```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local"
  backend to the newly configured "s3" backend. No existing state
  was found in the newly configured "s3" backend. Do you want to
  copy this state to the new "s3" backend? Enter "yes" to copy and
  "no" to start with an empty state.

  Enter a value:
```

Answer `yes` to copy your existing state into S3:

```
Successfully configured the backend "s3"! Terraform will
automatically use this backend unless the backend configuration
changes.
```

> If you answer `no` by mistake, your state is still on disk; upload it with `terraform state push terraform.tfstate`.

### 6. Verify the Migration

Confirm Terraform still tracks all three resources:

```bash
terraform state list
```

```
aws_security_group.app
aws_subnet.app
aws_vpc.main
```

Pull the state directly from the backend to prove it is served from S3:

```bash
terraform state pull | head -n 7
```

```
{
  "version": 4,
  "terraform_version": "1.12.2",
  "serial": 1,
  "lineage": "3f8a2c71-example-lineage-uuid",
  "outputs": {},
  "resources": [
```

You can also open the S3 console and find the `terraform.tfstate` object under `networking/` in your state bucket.

Run a plan against the remote state:

```bash
terraform plan
```

```
No changes. Your infrastructure matches the configuration.
```

The local `terraform.tfstate` is now a stale copy. Delete it:

```bash
rm terraform.tfstate
```

### 7. Break and Repair a State Lock

In `main.tf`, add a `Purpose` tag to the security group so there is a change to apply later:

```hcl
  tags = {
    Name        = "${var.prefix}-app-sg"
    Environment = var.environment
    Purpose     = "lab-locking-demo"
  }
```

Start a plan in the background, give it two seconds to acquire the lock, then kill the process before it can release the lock:

```bash
terraform plan > /dev/null 2>&1 &
sleep 2 && kill -9 $!
```

The lock is now stranded in S3. Run a normal plan:

```bash
terraform plan
```

```
Error: Error acquiring the state lock

Error message: operation error S3: PutObject, https response
error StatusCode: 412, ... PreconditionFailed: At least one of
the preconditions you specified did not hold

Lock Info:
  ID:        b7a4e6c2-7c2d-4f7a-9d31-example0001
  Path:      lab-tf-state-123456789012/networking/terraform.tfstate
  Operation: OperationTypePlan
  Who:       user@codespace
  Version:   1.12.2
  Created:   2026-07-09 14:25:03 UTC
```

> If you see a normal plan instead of this error, the plan finished before the kill landed; run the two background commands again.

Record the `ID` value from the `Lock Info` block. To see the lock itself, open the S3 console: a `terraform.tfstate.tflock` object is sitting next to the state file under `networking/`.

Remove the stranded lock with `force-unlock`, substituting your lock ID:

```bash
terraform force-unlock b7a4e6c2-7c2d-4f7a-9d31-example0001
```

```
Do you really want to force-unlock?
  Terraform will remove the lock on the remote state.
  This will allow local Terraform commands to modify this state,
  even though it may still be in use. Only 'yes' will be accepted
  to confirm.

  Enter a value: yes

Terraform state has been successfully unlocked!
```

Force-unlock is safe here because the process that held the lock is dead. If the lock holder is alive and just slow, use `-lock-timeout` instead (for example, `terraform plan -lock-timeout=60s`).

Confirm the lock is gone and apply the pending tag change:

```bash
terraform plan
```

```
Plan: 0 to add, 1 to change, 0 to destroy.
```

```bash
terraform apply -auto-approve
```

```
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

### 8. View State File Versions

Open the S3 console, click into your state bucket, open the `networking/` folder, and turn on the **Show versions** toggle. The state file has at least two versions: one from the migration in Step 5 and one from the apply in Step 7. Any previous version can be restored if the current state is ever corrupted. Old versions of `terraform.tfstate.tflock` appear too; they are removed when the bucket is destroyed.

### 9. Migrate State Back to Local

The same recipe works in any direction: change the backend configuration, then run `terraform init -migrate-state`. In `providers.tf`, delete (or comment out) the entire `backend "s3"` block, then run:

```bash
terraform init -migrate-state
```

```
Initializing the backend...
Terraform has detected you're unconfiguring your previously set
"s3" backend.

Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "s3"
  backend to the newly configured "local" backend. No existing
  state was found in the newly configured "local" backend. Do you
  want to copy this state to the new "local" backend? Enter "yes"
  to copy and "no" to start with an empty state.

  Enter a value:
```

Answer `yes`. If you answer `no` by mistake, re-add the backend block, run `terraform init -reconfigure`, and start this step over.

Verify the round trip:

```bash
terraform state list
ls -l terraform.tfstate
```

All three resources are still tracked, and `terraform.tfstate` is back on local disk.

## Clean Up

Destroy the networking resources:

```bash
terraform destroy -auto-approve
```

Destroy the state bucket (`force_destroy = true` empties it first, including the stale state copy and all old versions):

```bash
cd s3_backend
terraform destroy -auto-approve
```

Remove the leftover local state files:

```bash
cd ..
rm -f terraform.tfstate terraform.tfstate.backup
rm -f s3_backend/terraform.tfstate s3_backend/terraform.tfstate.backup
```

## Key Concepts

- Backend configuration is evaluated before anything else: values must be literals, and any change requires re-running `terraform init`.
- `terraform init -migrate-state` copies state between any two backends, in either direction. The `-reconfigure` flag switches backends **without** copying state.
- `use_lockfile = true` creates a `.tflock` object next to the state file using an S3 conditional write; the 412 `PreconditionFailed` error in Step 7 was S3 rejecting a second lock. The lock object is deleted when the operation ends, so only a killed process leaves a stale lock.
- DynamoDB locking (the `dynamodb_table` argument) is deprecated as of Terraform 1.11; `use_lockfile` replaces it. Both can be enabled together during a transition.
- `terraform force-unlock` removes a stale lock and requires the lock ID; `-lock-timeout` waits for a live one.
- `encrypt = true` encrypts the state object at rest; bucket versioning makes every state write recoverable.

## Additional Challenge

1. Change the `key` argument to `networking/v2/terraform.tfstate` and migrate the state to its new path with `terraform init -migrate-state`. Confirm in the S3 console that the object moved — and notice the old object is left behind as a stale copy.
2. Re-create the stranded lock from Step 7, but this time run `terraform plan -lock-timeout=120s` and watch it retry instead of failing immediately, then force-unlock from where you left off.
3. Run `terraform force-unlock -help` and read the description. When would you need it, and why does it demand the lock ID as an argument?
