# LAB-07-GH: Simplifying Code with Local Values

## Overview
In this lab, you will learn how to use Terraform's `locals` blocks to refactor repetitive code, create computed values, and make your configurations more dynamic. You'll take an existing configuration with redundant elements and improve it by centralizing common values and creating more maintainable infrastructure code.

[![Lab 07](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed
- GitHub account
- GitHub personal access token
- Basic understanding of Terraform and GitHub concepts

Note: GitHub credentials are required for this lab.

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
- Repeated repository configurations
- Redundant team descriptions
- Repetitive repository permission assignments
- Hardcoded naming patterns
- No centralized management of common elements

## Lab Steps

### 1. Configure GitHub Credentials

Set up your GitHub personal access token:

```bash
export GITHUB_TOKEN="your_personal_access_token"
```

### 2. Add Data Sources

Add the following data source to the top of `main.tf`:

```hcl
# Get information about the current user
data "github_user" "current" {
  username = ""
}
```

### 3. Create Locals Block

Add a locals block at the top of `main.tf` (after the `data` source):

```hcl
locals {
  # Common repository features
  repo_features = {
    has_issues      = true
    has_wiki        = true
    has_discussions = true
    has_projects    = true
    auto_init       = true
  }
  
  # Common repository merge settings
  merge_settings = {
    allow_merge_commit     = true
    allow_rebase_merge     = true
    allow_squash_merge     = true
    delete_branch_on_merge = true
  }
  
  # Common topics
  common_topics = [
    var.environment,
    "terraform-demo",
    "infrastructure-team"
  ]
  
  # Common name prefix for resources
  name_prefix = "${var.environment}-"
  
  # Managed by information
  managed_by = "Managed by Terraform (${data.github_user.current.login})"
}
```

### 4. Refactor Resources

Replace the resources in `main.tf` with these refactored versions:

```hcl
resource "github_repository" "app" {
  name        = "${local.name_prefix}application"   # <-- update value here
  description = "${title(var.environment)} application repository. ${local.managed_by}"   # <-- update value here
  visibility  = "public"

  has_issues      = local.repo_features.has_issues       # <-- update value here
  has_wiki        = local.repo_features.has_wiki         # <-- update value here
  has_discussions = local.repo_features.has_discussions  # <-- update value here

  allow_merge_commit     = local.merge_settings.allow_merge_commit       # <-- update value here
  allow_rebase_merge     = local.merge_settings.allow_rebase_merge       # <-- update value here
  allow_squash_merge     = local.merge_settings.allow_squash_merge       # <-- update value here
  
  delete_branch_on_merge = local.merge_settings.delete_branch_on_merge   # <-- update value here
  auto_init              = local.repo_features.auto_init                 # <-- update value here

  topics = concat(local.common_topics, ["application"])                  # <-- update value here
}

resource "github_repository" "docs" {
  name        = "${local.name_prefix}documentation"
  description = "${title(var.environment)} documentation repository. ${local.managed_by}"   # <-- update value here
  visibility  = "public"

  has_issues      = local.repo_features.has_issues       # <-- update value here
  has_wiki        = local.repo_features.has_wiki         # <-- update value here
  has_discussions = local.repo_features.has_discussions  # <-- update value here

  allow_merge_commit     = local.merge_settings.allow_merge_commit       # <-- update value here
  allow_rebase_merge     = local.merge_settings.allow_rebase_merge       # <-- update value here
  allow_squash_merge     = local.merge_settings.allow_squash_merge       # <-- update value here
  
  delete_branch_on_merge = local.merge_settings.delete_branch_on_merge   # <-- update value here
  
  auto_init = local.repo_features.auto_init                              # <-- update value here

  topics = concat(local.common_topics, ["documentation"])                # <-- update value here
}
```

### 5. Create Outputs File

Create an `outputs.tf` file:

```hcl
output "app_repo_url" {
  description = "URL of the application repository"
  value       = github_repository.app.html_url
}

output "docs_repo_url" {
  description = "URL of the documentation repository"
  value       = github_repository.docs.html_url
}

output "current_user" {
  description = "Username of the authenticated user"
  value       = data.github_user.current.login
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

Review the created resources in GitHub:
- Notice the consistent naming convention based on the environment variable
- Observe how all repositories have the same features
- Check how teams and repositories are created with the name prefix

### 7. Update Locals and Observe Changes

Now, let's demonstrate the power of centralized configuration by updating our locals block:

1. Modify the locals block in `main.tf` to update some values:

```hcl
locals {
  # Common repository features
  repo_features = {
    has_issues      = true
    has_wiki        = false          # <-- Changed wiki feature
    has_discussions = true
    has_projects    = true
    auto_init       = true
  }
  
  # Common repository merge settings
  merge_settings = {
    allow_merge_commit     = false   # <-- Changed merge setting
    allow_rebase_merge     = true
    allow_squash_merge     = true
    delete_branch_on_merge = true
  }
  
  # Common topics
  common_topics = [
    var.environment,
    "terraform-improved-demo",       # <-- Changed from "terraform-demo"
    "devops-team"                    # <-- Changed from "infrastructure-team"
  ]
  
  # Common name prefix for resources
  name_prefix = "${var.environment}-tf-"     # <-- Added "tf-" to the prefix
  
  # Managed by information
  managed_by = "Managed by Terraform (${data.github_user.current.login})"
}
```

2. Modify the `variables` file to change the environment:

```hcl
variable "environment" {
  description = "Environment name for resource naming"
  type        = string
  default     = "dev"      # <-- Changed from "production" to "dev"
}
```

3. Apply the changes and observe the results:

```bash
terraform plan
terraform apply
```

4. Check GitHub again and notice:
   - All resources have been recreated with new names
   - All repository names now include "dev-tf-" instead of "production-"
   - Wikis are now disabled across all repositories
   - Merge commits are no longer allowed
   - Topics have been updated
   - These changes were made by modifying only the locals block and tfvars file

This demonstrates how using locals allows you to make widespread changes to your infrastructure by modifying just a few values in a central location.

### 8. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Additional Exercises

1. Add more computed values to the locals block
2. Create local variables for team permissions
3. Add conditional features based on the environment
4. Experiment with different repository settings