# LAB-15-AWS: Creating and Using Local Modules

## Overview
In this lab, you will create your own local Terraform modules and use them to build AWS IAM resources. You'll create two modules - one for IAM policies and one for IAM roles - and then call these modules from a parent configuration. You'll then refactor the module calls to use the `for_each` meta-argument and use `moved` blocks to update resource addresses without destroying any infrastructure. This lab teaches you how to build reusable modules, pass variables between modules, inspect module resources in state, and refactor module code safely. All resources created in this lab are part of the AWS free tier.

[![Lab 15](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/aws_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed
- AWS free tier account
- Basic understanding of Terraform and AWS IAM concepts

Note: AWS credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each **lab** to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time
55 minutes

## Lab Steps

### 1. Configure AWS Credentials

Set up your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
```

### 2. Create the Directory Structure

Create the following directory structure for your project:

```bash
mkdir -p modules/iam_policy
mkdir -p modules/iam_role
```

Alternatively, you can create these directories and files using the VSCode UI if you prefer:
- Right-click in the Explorer panel and select "**New Folder**" to create the "**modules**" directory
- Right-click on "**modules**" and create the "**iam_policy**" and "**iam_role**" subdirectories
- Right-click in the main directory and select "**New File**" to create each of the `.tf` files

### 3. Create the Providers File

Add the following content to `providers.tf` if it doesn't already exist:

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
  region = var.region
}
```

### 4. Create the Variables File

Add the following content to `variables.tf` if it doesn't already exist:

```hcl
variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
```

### 5. Create the IAM Policy Module

Create the following files in the `modules/iam_policy` directory:

#### 5.1. Create `modules/iam_policy/variables.tf`:

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "policy_name" {
  description = "Name of the IAM policy"
  type        = string
}

variable "policy_description" {
  description = "Description of the IAM policy"
  type        = string
}

variable "policy_statements" {
  description = "List of policy statements"
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
}
```

#### 5.2. Create `modules/iam_policy/main.tf`:

```hcl
resource "aws_iam_policy" "policy" {
  name        = "${var.environment}-${var.policy_name}"
  path        = "/"
  description = var.policy_description

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for statement in var.policy_statements : {
        Effect   = statement.effect
        Action   = statement.actions
        Resource = statement.resources
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

#### 5.3. Create `modules/iam_policy/outputs.tf`:

```hcl
output "policy_arn" {
  description = "ARN of the IAM policy"
  value       = aws_iam_policy.policy.arn
}

output "policy_name" {
  description = "Name of the IAM policy"
  value       = aws_iam_policy.policy.name
}

output "policy_id" {
  description = "ID of the IAM policy"
  value       = aws_iam_policy.policy.id
}
```

### 6. Create the IAM Role Module

Create the following files in the `modules/iam_role` directory:

#### 6.1. Create `modules/iam_role/variables.tf`:

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "role_description" {
  description = "Description of the IAM role"
  type        = string
}

variable "trusted_principal" {
  description = "AWS service principal that can assume this role"
  type        = string
}

variable "policy_arns" {
  description = "Map of policy ARNs to attach to the role, keyed by a static name"
  type        = map(string)
  default     = {}
}
```

#### 6.2. Create `modules/iam_role/main.tf`:

```hcl
resource "aws_iam_role" "role" {
  name        = "${var.environment}-${var.role_name}"
  description = var.role_description

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = var.trusted_principal
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "policy_attachments" {
  for_each   = var.policy_arns
  role       = aws_iam_role.role.name
  policy_arn = each.value
}
```

**Learning Note**: The `policy_arns` variable is a map instead of a list. The `for_each` meta-argument requires its keys to be known at plan time. The policy ARNs are not known until the policies are created, but the map keys (like `s3_read_only`) are static strings, so Terraform can plan the attachments. Using `for_each = toset(var.policy_arns)` with a list of ARNs would fail with an `Invalid for_each argument` error on the first apply because the values in the set would not be known yet.

#### 6.3. Create `modules/iam_role/outputs.tf`:

```hcl
output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.role.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.role.name
}

output "role_id" {
  description = "ID of the IAM role"
  value       = aws_iam_role.role.id
}
```

### 7. Create the Main Configuration

Add the following content to `main.tf` to use your local modules:

```hcl
# Create IAM policies using the iam_policy module
module "s3_read_only_policy" {
  source             = "./modules/iam_policy"
  environment        = var.environment
  policy_name        = "s3-read-only"
  policy_description = "Allow read-only access to S3"
  policy_statements = [
    {
      effect    = "Allow"
      actions   = ["s3:Get*", "s3:List*"]
      resources = ["*"]
    }
  ]
}

module "cloudwatch_write_policy" {
  source             = "./modules/iam_policy"
  environment        = var.environment
  policy_name        = "cloudwatch-write"
  policy_description = "Allow CloudWatch write access"
  policy_statements = [
    {
      effect    = "Allow"
      actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      resources = ["*"]
    }
  ]
}

# Create IAM roles and associate with policies
module "app_role" {
  source            = "./modules/iam_role"
  environment       = var.environment
  role_name         = "app-role"
  role_description  = "Application role"
  trusted_principal = "ec2.amazonaws.com"
  policy_arns = {
    s3_read_only = module.s3_read_only_policy.policy_arn
  }
}

module "monitoring_role" {
  source            = "./modules/iam_role"
  environment       = var.environment
  role_name         = "monitoring-role"
  role_description  = "Monitoring role"
  trusted_principal = "lambda.amazonaws.com"
  policy_arns = {
    cloudwatch_write = module.cloudwatch_write_policy.policy_arn
  }
}
```

### 8. Create the Outputs File

Add the following content to `outputs.tf`:

```hcl
output "policy_arns" {
  description = "ARNs of the created IAM policies"
  value = {
    s3_read_only     = module.s3_read_only_policy.policy_arn,
    cloudwatch_write = module.cloudwatch_write_policy.policy_arn
  }
}

output "role_arns" {
  description = "ARNs of the created IAM roles"
  value = {
    app_role        = module.app_role.role_arn,
    monitoring_role = module.monitoring_role.role_arn
  }
}

output "role_names" {
  description = "Names of the created IAM roles"
  value = {
    app_role        = module.app_role.role_name,
    monitoring_role = module.monitoring_role.role_name
  }
}
```

### 9. Format all files in the current and subdirectories

Run a terraform fmt but include all subdirectories as well - this will format our parent/calling module as well as all the files within our module directories:

```bash
terraform fmt -recursive
```

### 10. Initialize and Apply

Initialize and apply the configuration:

```bash
terraform init
terraform plan
terraform apply
```

Watch how Terraform:
- Processes each local module
- Creates the IAM policies using the `iam_policy` module
- Creates the IAM roles using the `iam_role` module
- Attaches the appropriate policies to each role

### 11. Inspect Module Resources in State

With the resources created, look at how Terraform tracks module resources in state:

```bash
terraform state list
```

Expected output:

```
module.app_role.aws_iam_role.role
module.app_role.aws_iam_role_policy_attachment.policy_attachments["s3_read_only"]
module.cloudwatch_write_policy.aws_iam_policy.policy
module.monitoring_role.aws_iam_role.role
module.monitoring_role.aws_iam_role_policy_attachment.policy_attachments["cloudwatch_write"]
module.s3_read_only_policy.aws_iam_policy.policy
```

Resources created inside a module are addressed using the pattern `module.<module_name>.<resource_type>.<resource_name>`.

Inspect a single module resource to see its full attributes:

```bash
terraform state show module.s3_read_only_policy.aws_iam_policy.policy
```

### 12. Refactor the Policy Module Calls with for_each

The two policy module blocks in `main.tf` are nearly identical. Just like resources, module calls support the `for_each` meta-argument, so a single module block can create multiple instances from a map.

#### 12.1. Add the following variable to `variables.tf`:

```hcl
variable "policies" {
  description = "Map of IAM policies to create"
  type = map(object({
    description = string
    statements = list(object({
      effect    = string
      actions   = list(string)
      resources = list(string)
    }))
  }))
  default = {
    "s3-read-only" = {
      description = "Allow read-only access to S3"
      statements = [
        {
          effect    = "Allow"
          actions   = ["s3:Get*", "s3:List*"]
          resources = ["*"]
        }
      ]
    }
    "cloudwatch-write" = {
      description = "Allow CloudWatch write access"
      statements = [
        {
          effect    = "Allow"
          actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          resources = ["*"]
        }
      ]
    }
  }
}
```

#### 12.2. In `main.tf`, remove the `s3_read_only_policy` and `cloudwatch_write_policy` module blocks and replace them with a single module block:

```hcl
# Create IAM policies using the iam_policy module
module "policies" {
  source             = "./modules/iam_policy"
  for_each           = var.policies
  environment        = var.environment
  policy_name        = each.key
  policy_description = each.value.description
  policy_statements  = each.value.statements
}
```

#### 12.3. Update the `policy_arns` argument in both role module blocks to reference the new module instances:

```hcl
module "app_role" {
  source            = "./modules/iam_role"
  environment       = var.environment
  role_name         = "app-role"
  role_description  = "Application role"
  trusted_principal = "ec2.amazonaws.com"
  policy_arns = {
    s3_read_only = module.policies["s3-read-only"].policy_arn
  }
}

module "monitoring_role" {
  source            = "./modules/iam_role"
  environment       = var.environment
  role_name         = "monitoring-role"
  role_description  = "Monitoring role"
  trusted_principal = "lambda.amazonaws.com"
  policy_arns = {
    cloudwatch_write = module.policies["cloudwatch-write"].policy_arn
  }
}
```

#### 12.4. Update the `policy_arns` output in `outputs.tf`:

```hcl
output "policy_arns" {
  description = "ARNs of the created IAM policies"
  value       = { for k, v in module.policies : k => v.policy_arn }
}
```

Run a plan and carefully examine the output:

```bash
terraform plan
```

**IMPORTANT**: Terraform proposes destroying both existing policies, creating two new ones, and replacing the policy attachments. The infrastructure is identical, but the resource addresses changed (`module.s3_read_only_policy` became `module.policies["s3-read-only"]`), and Terraform tracks resources by address. In production, applying this would briefly remove permissions from the roles, and it could even fail because the new policies use the same names as the old ones, which may not be destroyed yet when the new ones are created.

**DO NOT APPLY these changes.** We will fix this in the next step.

### 13. Move Resources to Their New Addresses with Moved Blocks

Terraform's `moved` block tells Terraform that a resource or module has a new address, so it updates the state instead of destroying and recreating the infrastructure.

Add the following `moved` blocks to `main.tf`, above the `policies` module block:

```hcl
moved {
  from = module.s3_read_only_policy
  to   = module.policies["s3-read-only"]
}

moved {
  from = module.cloudwatch_write_policy
  to   = module.policies["cloudwatch-write"]
}
```

Run the plan again:

```bash
terraform plan
```

This time the plan shows `0 to add, 0 to change, 0 to destroy`. Instead, Terraform reports that the existing policies will move to their new addresses. You will also see a `Changes to Outputs` section for the updated `policy_arns` output, which does not modify any infrastructure.

Apply the changes:

```bash
terraform apply
```

Verify the new addresses in state:

```bash
terraform state list
```

The policies now appear under their `for_each` based addresses:

```
module.policies["cloudwatch-write"].aws_iam_policy.policy
module.policies["s3-read-only"].aws_iam_policy.policy
```

**TIP**: The same result can be achieved imperatively with the `terraform state mv` command. Moved blocks are the declarative approach and can be committed to version control so every user of the configuration performs the same move. Once the move has been applied, the `moved` blocks can be safely removed from the configuration.

### 14. Modify a Module to See Changes

Let's modify the IAM policy module to add some additional tags.

Update `modules/iam_policy/main.tf`:

```hcl
resource "aws_iam_policy" "policy" {
  name        = "${var.environment}-${var.policy_name}"
  path        = "/"
  description = var.policy_description

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for statement in var.policy_statements : {
        Effect   = statement.effect
        Action   = statement.actions
        Resource = statement.resources
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "iam_policy"                            # <-- add the new tag here
    Name        = "${var.environment}-${var.policy_name}" # <-- add the new tag here
  }
}
```

Apply the changes:

```bash
terraform apply
```

Notice how Terraform detects the changes in the module and updates only the affected resources. Both policy instances receive the new tags because they are created from the same module source. Changing the module in one place updates every instance that uses it.

### 15. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Understanding Local Modules

Let's examine the key aspects of creating and using local modules:

### Module Structure
A well-structured module typically contains:
- `main.tf` - The main resource definitions
- `variables.tf` - Input variable definitions
- `outputs.tf` - Output definitions

### Module Source
For local modules, the source is a relative path:
```
source = "./modules/iam_policy"
```

### Module Inputs
Modules receive input through variables set in the module block:
```
module "policies" {
  for_each    = var.policies
  policy_name = each.key
  ...
}
```

### Module Outputs
Modules provide outputs that can be referenced by their address:
```
module.policies["s3-read-only"].policy_arn
```

### Module Reuse
The same module can be called multiple times, either with separate module blocks (like the two role modules) or with `for_each` (like the `policies` module).

### Moved Blocks
Refactoring changes resource addresses, and Terraform tracks resources by address. Moved blocks update the state so Terraform does not destroy and recreate the infrastructure:
```
moved {
  from = module.s3_read_only_policy
  to   = module.policies["s3-read-only"]
}
```

## Benefits of Using Local Modules

1. **Code Reusability**: Write once, use multiple times
2. **Encapsulation**: Hide complex logic within modules
3. **Maintainability**: Change the module in one place, effects apply everywhere
4. **Organization**: Structured approach to managing resources
5. **Testing**: Modules can be tested independently
6. **Composability**: Combine modules to create complex architectures

## Additional Exercises

1. Add another policy to the `policies` variable and apply the changes
2. Refactor the two role module calls to use `for_each` with a map variable
3. Modify the role module to support custom inline policies
4. Create a third module for IAM users and have it use the `policies` module
5. Add conditional creation of resources within the modules

## Success Criteria

- Two local modules created, each with `variables.tf`, `main.tf`, and `outputs.tf`
- IAM policies and roles created through module calls
- Module resources visible in state using module addressing
- Policy module calls refactored to `for_each` without destroying resources
- `moved` blocks used to update resource addresses in state
- A module change propagated to every instance that uses the module
- All resources destroyed during cleanup