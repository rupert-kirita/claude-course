# LAB-10-GH: Managing Explicit Dependencies with depends_on

## Overview
This lab demonstrates how to use Terraform's `depends_on` meta-argument with GitHub resources. You'll learn when to use explicit dependencies versus relying on implicit dependencies, using free GitHub resources.

[![Lab 10](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml)

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
15 minutes

## Existing Configuration Files

The lab directory contains the following initial files:

 - `main.tf`
 - `providers.tf`
 - `variables.tf`

## Lab Steps

### 1. Identify Implicit Dependencies

Examine the `main.tf` file and identify the implicit dependencies:
- Repository File depends on Repository (via repository attribute - line 13)
- Issue Label depends on Repository (via repository attribute - line 25)

### 2. Initialize Terraform

Set up your GitHub token as an environment variable:
```bash
export GITHUB_TOKEN="your-personal-access-token"
```

Initialize your Terraform workspace:
```bash
terraform init
```

### 3. Run an Initial Plan and Apply

Create the initial resources:
```bash
terraform plan
terraform apply
```

Notice how Terraform automatically determines the correct order based on implicit dependencies. It first creates the repository, then creates the other two resources in parallel.

### 6. Add Resources with Explicit Dependencies

Now, add the following resources that require explicit dependencies:

```hcl
# Additional Repository Files with explicit dependency
resource "github_repository_file" "contributing" {
  repository          = github_repository.main.name
  branch              = var.default_branch
  file                = "CONTRIBUTING.md"
  content             = "# Contributing Guidelines\n\nThank you for your interest in contributing to this project."
  commit_message      = "Add CONTRIBUTING.md"
  commit_author       = "Terraform"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true

  # Explicitly depend on branch protection rule
  # This ensures the branch is protected before adding files
  depends_on = [github_repository.main]
}

# Additional Label with explicit dependency
resource "github_issue_label" "enhancement" {
  repository  = github_repository.main.name
  name        = "enhancement"
  color       = "00FF00"
  description = "Enhancement requests"
  
  # Explicitly depend on the first label and team access
  # This ensures labels are created in a specific order
  depends_on = [
    github_issue_label.bug
  ]
}
```

### 8. Apply and Observe Order
```bash
terraform apply
```

Watch how Terraform respects both your implicit and explicit dependencies.

### 9. Add Outputs

Create an outputs.tf file:

```hcl
output "repository_name" {
  description = "Name of the GitHub repository"
  value       = github_repository.main.name
}

output "repository_url" {
  description = "URL of the GitHub repository"
  value       = github_repository.main.html_url
}

output "files_created" {
  description = "Files created in the repository"
  value = [
    github_repository_file.readme.file,
    github_repository_file.contributing.file
  ]
}

output "dependency_example" {
  description = "Example of dependencies in this lab"
  value = {
    "Implicit dependencies" = "Repository -> Repository File, Repository -> Issue Label, Team -> Team Repository Access"
    "Explicit dependencies" = "Label/Team Access -> Enhancement Label, Files"
  }
}
```

### 10. Apply to See Outputs
```bash
terraform apply
```

### 11. Clean Up Resources

When you're done, clean up all resources:
```bash
terraform destroy
```

## Understanding depends_on

### When to Use depends_on:
1. When there's no implicit dependency (no reference to another resource's attributes)
2. When a resource needs to be created after another, even though they don't directly reference each other
3. When you need to ensure a specific creation order for resources

### Examples in GitHub:
- Repository files that should be created after branch protection rules are in place
- Webhooks that should be created after a repository is fully configured
- Labels or other resources that need to be created in a specific order

### Syntax:
```hcl
resource "github_example" "example" {
  # ... configuration ...
  
  depends_on = [
    github_other_resource.name
  ]
}
```

## Additional Exercises

1. Add project boards with dependencies on repositories
2. Create multiple repositories with cross-repository dependencies
3. Set up organization-level resources with dependencies on team resources
4. Try creating a dependency chain across different GitHub resource types