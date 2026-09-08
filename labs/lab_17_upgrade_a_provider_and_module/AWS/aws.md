# LAB-17-AWS: Upgrading a Terraform Provider and Module

This lab demonstrates how to safely upgrade a Terraform provider and a community module to newer versions. You'll learn how to interpret version constraints, inspect the `.terraform.lock.hcl` file, and use `terraform init -upgrade` to pull in updated dependencies — all using free AWS resources.

[![Lab 17](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml)

**Preview Mode:** Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

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
20 minutes

## Initial Configuration Files

The lab directory contains the following initial files used for the lab - some of which are empty files:

 - `main.tf`
 - `variables.tf`
 - `providers.tf`

## Lab Steps

### Task 1: Configure AWS Credentials

Set up your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
```

### Task 2: Create a New Working Directory and Initial Configuration

In this task, you'll create a fresh working directory and write a Terraform configuration that intentionally uses **older** pinned versions of both the AWS provider and the popular `terraform-aws-modules/vpc/aws` community module.

Create and navigate to a new working directory:

```bash
cd labs/lab_17_upgrade_a_provider_and_module/AWS
```

Add the following to the `providers.tf` file to declare the required providers with an older version constraint:

```hcl
terraform {
  required_version = ">= 1.12.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.20"
    }
  }
}
```

Ad the following blocks to th `main.tf` file for a VPC module (pinned to an older version) and a standalone S3 bucket resource:

```hcl
provider "aws" {
  region = "us-east-1"
}

# Using a pinned older version of the community VPC module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "lab-upgrade-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Name        = "lab-upgrade-vpc"
    Terraform   = "true"
    Environment = "lab"
  }
}

# Note: S3 bucket names must be globally unique — replace the suffix below with your own value
resource "aws_s3_bucket" "lab" {
  bucket = "terraform-upgrade-lab-yourname"

  tags = {
    Name        = "Terraform Upgrade Lab Bucket"
    Terraform   = "true"
    Environment = "lab"
  }
}
```

> ⚠️ **Important:** Replace `yourname` in the S3 bucket name with a unique value (e.g., your initials and today's date). S3 bucket names must be globally unique across all AWS accounts.

Add the following to the `outputs.tf` file so you can verify what was created:

```hcl
output "vpc_id" {
  description = "The ID of the lab VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.lab.id
}
```

---

### Task 3: Initialize and Deploy the Initial Infrastructure

Run `terraform init` to download the pinned provider and module versions:

```bash
terraform init
```

You should see output similar to the following, confirming which versions were installed:

```
Initializing the backend...
Initializing modules...
Downloading registry.terraform.io/terraform-aws-modules/vpc/aws 5.1.2 for vpc...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.20"...
- Installing hashicorp/aws v5.100.1...

Terraform has been successfully initialized!
```

Run `terraform plan` to preview the resources that will be created:

```bash
terraform plan
```

Review the plan output. You should see the VPC, two public subnets, two private subnets, route tables, and the S3 bucket.

Apply the configuration to create the resources:

```bash
terraform apply
```

Type `yes` when prompted to confirm. Once complete, review the outputs to confirm your resources were successfully created.

---

### Task 4: Inspect the Lock File

After `terraform init`, Terraform generates a `.terraform.lock.hcl` file to record the exact provider versions that were selected. This file should always be committed to version control.

Open the lock file and examine its contents:

```bash
cat .terraform.lock.hcl
```

You will see an entry for the AWS provider that looks similar to this:

```hcl
provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.20.1"
  constraints = "~> 5.20"
  hashes = [
    "h1:...",
    ...
  ]
}
```

Notice that the lock file records:

- The **exact version** that was installed (e.g., `5.100.0`)
- The **constraint** from your configuration (`~> 5.20`)
- **Cryptographic hashes** to ensure integrity on future downloads

> 💡 The lock file ensures that every teammate running `terraform init` on this configuration will get the exact same provider version — even if newer patch releases have been published since you first ran `init`.

Note that the **module version** is recorded differently — it appears in the `.terraform/modules/modules.json` file. You can inspect it with:

```bash
cat .terraform/modules/modules.json
```

You should see the module source and version (`5.1.2`) recorded there.

---

### Task 5: Upgrade the Provider Version

Your organization has decided to upgrade to the latest AWS provider `6.x` release to take advantage of new resource support and bug fixes.

Open `terraform.tf` and update the AWS provider version constraint from `~> 5.20` to `~> 6.0`:

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
```

If you run `terraform plan` at this point, Terraform will return an error because the lock file still references `5.20.x`, which no longer satisfies the new constraint. Try it to see the error:

```bash
terraform plan
```

You should see an error like:

```
Error: Inconsistent dependency lock file
│ 
│ The following dependency selections recorded in the lock file are inconsistent with the current configuration:
│   - provider registry.terraform.io/hashicorp/aws: locked version selection 5.100.0 doesn't match the updated version constraints ">= 5.0.0, ~> 6.0"
│ 
│ To update the locked dependency selections to match a changed configuration, run:
│   terraform init -upgrade

```bash
terraform init -upgrade
```

Terraform will now resolve and install a version that satisfies `~> 6.0`. Confirm that the lock file has been updated:

```bash
cat .terraform.lock.hcl
```

You should now see a newer version recorded (e.g., `6.0` or later) along with updated hashes.

---

### Task 6: Upgrade the Module Version

Next, you'll upgrade the community VPC module from `5.1.2` to `5.8.1`. Module upgrades may include new input variables, additional sub-resources, or updated defaults — always review the module's CHANGELOG before upgrading in production.

Open `main.tf` and update the `version` argument in the `module "vpc"` block:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "lab-upgrade-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Name        = "lab-upgrade-vpc"
    Terraform   = "true"
    Environment = "lab"
  }
}
```

Run `terraform init -upgrade` again to download the updated module version:

```bash
terraform init -upgrade
```

You should see output confirming the new module version is being downloaded:

```
Downloading registry.terraform.io/terraform-aws-modules/vpc/aws 5.8.1 for vpc...
```

Verify the module version has been updated in the modules manifest:

```bash
cat .terraform/modules/modules.json
```

---

### Task 7: Plan and Apply the Upgraded Configuration

Now that both the provider and module have been upgraded, run a plan to see if any infrastructure changes are required:

```bash
terraform plan
```

In many cases, a minor module or provider upgrade will result in **no infrastructure changes** — particularly when only new features or internal fixes were introduced. However, some upgrades introduce behavioral changes or new defaults that may result in planned modifications.

Review the plan output carefully before proceeding. If the plan shows only changes you expect (or no changes at all), apply the configuration:

```bash
terraform apply
```

Type `yes` when prompted. Confirm the outputs are still correct after the upgrade:

```bash
terraform output
```

Congrats, you've successfully upgraded both a Terraform provider and a community module while maintaining control over your infrastructure changes!

---

### Task 8: Clean Up Resources

Destroy all resources created during this lab to avoid any charges:

```bash
terraform destroy
```

Type `yes` when prompted. Verify in the AWS console that the VPC, subnets, and S3 bucket have been removed.

---

## Summary

In this lab, you:

- Pinned a Terraform provider and community module to specific older versions
- Deployed infrastructure using those pinned versions
- Inspected the `.terraform.lock.hcl` file to understand how versions are recorded and protected
- Upgraded the provider version constraint and used `terraform init -upgrade` to update the lock file
- Upgraded the module version by changing the `version` argument in the module block
- Applied the upgraded configuration and verified no unintended infrastructure changes occurred

---