# LAB-14-AWS: Using Terraform Registry Modules

## Overview
In this lab, you will learn how to use modules from the Terraform Registry by building up a module configuration step by step. You'll start with the smallest possible module block, watch Terraform download it during initialization, and then gradually pass in your own values using variables. You'll also upgrade the module to a newer version, add a second module, and use `for_each` to create multiple resources from a single module block. The lab uses AWS free-tier resources to ensure no costs are incurred.

[![Lab 14](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml)

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
20 minutes

## Initial Configuration Files

The lab directory contains the following initial files used for the lab - some of which are empty files:

 - `main.tf`
 - `variables.tf`
 - `providers.tf`

## Lab Steps

### 1. Configure AWS Credentials

Set up your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
```

### 2. Start with a Minimal Module Configuration

A module block only requires two things to get started: where to find the module (`source`) and what version to use (`version`). Add the following to `main.tf`:

```hcl
# Use the S3 bucket module from the Terraform Registry
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.12.0"
}
```

That's a complete, working module block. Everything else the module needs is handled by default values defined inside the module itself.

### 3. Initialize the Configuration to Download the Module

Modules are not part of the Terraform binary. When you reference a module from the Terraform Registry, Terraform has to download a copy of the module's code to your local machine. That happens during initialization:

```bash
terraform init
```

Look closely at the first few lines of the output:

```text
Initializing the backend...
Initializing modules...
Downloading registry.terraform.io/terraform-aws-modules/s3-bucket/aws 5.12.0 for s3_bucket...
- s3_bucket in .terraform/modules/s3_bucket
```

Terraform downloaded version `5.12.0` of the module and placed the code in the `.terraform` directory. You can see it for yourself:

```bash
ls .terraform/modules
```

```text
modules.json  s3_bucket
```

The `s3_bucket` directory contains the module's Terraform code, and `modules.json` is how Terraform keeps track of which modules are installed and where they came from. This is a key concept: the module code now lives locally in your working directory, pinned to the exact version you requested.

### 4. Pass Your Own Values to the Module

Right now the module would create a bucket using nothing but its defaults. In practice, you pass values into a module through its input variables, the same way you set arguments on a resource.

First, add a variable to `variables.tf` that you will use to name and tag your resources:

```hcl
variable "environment" {
  description = "Environment name used to prefix resources"
  type        = string
  default     = "dev"
}
```

Now update the module block in `main.tf` to pass in values. Each argument here maps to an input variable that the module author defined:

```hcl
# Use the S3 bucket module from the Terraform Registry
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.12.0"

  bucket_prefix = "${var.environment}-modules-lab-"

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    enabled = true
  }

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}
```

Notice what is happening here:
- `bucket_prefix` lets AWS generate a unique bucket name that starts with your prefix, since S3 bucket names must be globally unique
- The four public access settings and the `versioning` block override the module's defaults
- The `tags` value is built from your own variable, so the value flows from your `variables.tf` into the module

### 5. Add an Output for the Bucket Name

Modules also produce outputs. The S3 bucket module outputs the bucket name and ARN, among other values. Create an `outputs.tf` file to surface the bucket name:

```hcl
output "bucket_name" {
  description = "The name of the S3 bucket"
  value       = module.s3_bucket.s3_bucket_id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = module.s3_bucket.s3_bucket_arn
}
```

The syntax `module.<module_name>.<output_name>` is how you read a value out of a module.

### 6. Plan and Apply the Configuration

Review the plan, then apply the configuration:

```bash
terraform plan
terraform apply
```

Notice in the plan that a single module block created several resources, including the bucket, the versioning configuration, and the public access block. That's the value of a module: one block of configuration, written by experts and reused by thousands of teams, that manages multiple resources for you.

After the apply completes, note the `bucket_name` output. AWS generated a unique name that starts with your `dev-modules-lab-` prefix.

### 7. Upgrade the Module to a Newer Version

Module authors publish new versions over time. Because you pinned the version, your configuration keeps using `5.12.0` until you decide to upgrade. Update the `version` argument in the module block in `main.tf`:

```hcl
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.13.0"
```

Now run a plan without initializing first:

```bash
terraform plan
```

The plan fails with an error similar to this:

```text
Error: Module version requirements have changed

The version requirements have changed since this module was installed
and the installed version (5.12.0) is no longer acceptable. Run
"terraform init" to install all modules required by this
configuration.
```

Terraform noticed that the locally installed copy of the module no longer matches the version your configuration asks for. Just like the first time, downloading a module version is the job of `terraform init`:

```bash
terraform init
```

```text
Initializing modules...
Downloading registry.terraform.io/terraform-aws-modules/s3-bucket/aws 5.13.0 for s3_bucket...
- s3_bucket in .terraform/modules/s3_bucket
```

Terraform replaced the local copy with version `5.13.0`. Run a plan and apply to confirm your infrastructure is in sync with the new version:

```bash
terraform plan
terraform apply
```

Remember this workflow: any time you change a module version, run `terraform init` before anything else.

### 8. Add a Second Module for a VPC

Modules really shine when they manage many resources at once. Add the AWS VPC module to `main.tf`, along with two supporting variables in `variables.tf`.

Add to `variables.tf`:

```hcl
variable "region" {
  description = "AWS region for the VPC availability zones"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
```

Add to `main.tf`:

```hcl
# Use the VPC module from the Terraform Registry
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}
```

Try to plan again:

```bash
terraform plan
```

Once again the plan fails, this time because the VPC module has never been downloaded:

```text
Error: Module not installed

This configuration depends on module at module.vpc, which is not
installed. Run "terraform init" to install all modules required by
this configuration.
```

By now you know the fix:

```bash
terraform init
terraform plan
terraform apply
```

In the plan output, notice that this single module block creates over a dozen resources: the VPC itself, subnets, route tables, route table associations, and an internet gateway. Writing all of that by hand would take hundreds of lines of configuration.

### 9. Create Multiple Buckets with `for_each`

You can call the same module multiple times using the `for_each` meta-argument. Add a variable to `variables.tf` holding a simple list of names:

```hcl
variable "bucket_names" {
  description = "Names for the additional S3 buckets"
  type        = list(string)
  default     = ["logs", "images"]
}
```

Add a new module block to `main.tf` that loops over the list:

```hcl
# Create one bucket for each name in the list
module "s3_buckets" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.13.0"

  for_each = toset(var.bucket_names) # <-- Create a bucket for each name in the list

  bucket_prefix = "${var.environment}-${each.value}-"

  tags = {
    Terraform   = "true"
    Environment = var.environment
    Name        = each.value
  }
}
```

Terraform creates one instance of the module for each item in the list, and `each.value` holds the current name (`logs` or `images`) inside each instance.

You added a new module block, so initialize once more, then apply:

```bash
terraform init
terraform plan
terraform apply
```

The plan shows two new buckets, one prefixed `dev-logs-` and one prefixed `dev-images-`, both from a single module block.

To read an output from a specific instance, include the key in square brackets. Add this to `outputs.tf`, then run `terraform apply` to see the value:

```hcl
output "logs_bucket_name" {
  description = "The name of the logs bucket"
  value       = module.s3_buckets["logs"].s3_bucket_id
}
```

### 10. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Understanding Module Usage

Let's review the key concepts from this lab:

### Module Sources
The `source` attribute specifies where to find the module:
```
source = "terraform-aws-modules/s3-bucket/aws"
```
This format (`<NAMESPACE>/<NAME>/<PROVIDER>`) refers to modules in the public Terraform Registry.

### Module Versioning
The `version` attribute pins the module to a specific version:
```
version = "5.12.0"
```
Pinning protects you from unexpected changes when the module author publishes a new release. Upgrading is a deliberate action: you change the version number, then run `terraform init` to download the new code.

### When terraform init Is Required
You saw three situations in this lab that required running `terraform init`:
- Adding a module to the configuration for the first time
- Changing the version of a module that is already installed
- Adding a new module block, even one that uses an already downloaded source

A simple rule of thumb: if you touch a module's `source` or `version`, or add a new module block, run `terraform init`.

### Module Inputs
Modules accept input variables that control their behavior, and anything you don't set falls back to the module's defaults:
```
bucket_prefix = "${var.environment}-modules-lab-"
```

### Module Outputs
Modules provide outputs that you can read using the `module.<module_name>.<output_name>` syntax:
```
value = module.s3_bucket.s3_bucket_id
```

### Using For_Each with Modules
Modules can be instantiated multiple times using `for_each`:
```
for_each = toset(var.bucket_names)
```
This creates one module instance per item, and each instance is addressed by its key, such as `module.s3_buckets["logs"]`.

## Additional Resources

- [Terraform Registry](https://registry.terraform.io/)
- [AWS S3 Bucket Module Documentation](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws/latest)
- [AWS VPC Module Documentation](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)