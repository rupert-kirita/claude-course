# LAB-09-GH: Creating and Managing Resources with the For_Each Meta-Argument

## Overview
In this lab, you will learn how to use Terraform's `for_each` meta-argument to create and manage multiple GitHub resources efficiently. You'll discover how `for_each` differs from `count` and when to use each approach. The lab uses free GitHub resources to ensure no costs are incurred.

[![Lab 09](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed
- GitHub account
- GitHub personal access token
- Basic understanding of Terraform and GitHub concepts
- Familiarity with the `count` meta-argument

Note: GitHub credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each **lab** to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time
45 minutes

## Existing Configuration Files

The lab directory contains the following files with resources created using `count` that we'll refactor to use `for_each`:

 - `main.tf`
 - `providers.tf`
 - `variables.tf`
 
Examine these files and notice:
- Repository creation using count and numeric indexing
- Branch protection rules using count and referencing repositories by index
- Issue labels using count and modulo operations
- The potential issues if list elements are reordered or removed

## Lab Steps

### 1. Configure GitHub Credentials

Set up your GitHub personal access token:

```bash
export GITHUB_TOKEN="your_personal_access_token"
```

### 2. Update Variables for For_Each

Modify `variables.tf` to include map variables for use with `for_each`:

```hcl
# Keep the list variables to compare to the new variables you will add below
variable "repo_names" {
  description = "Names for repositories"
  type        = list(string)
  default     = ["repo-1", "repo-2", "repo-3"]
}

# New map variables for for_each
variable "repositories" {
  description = "Map of repository configurations"
  type        = map(string)
  default = {
    "api"      = "API service repository"
    "web"      = "Web frontend repository"
    "database" = "Database schema repository"
  }
}

variable "branch_patterns" {
  description = "Map of branch patterns to protect"
  type        = map(string)
  default = {
    "main"    = "Main branch"
    "release" = "Release branch"
  }
}

variable "label_config" {
  description = "Map of label configurations"
  type        = map(string)
  default = {
    "bug"     = "FF0000"
    "feature" = "00FF00"
    "docs"    = "0000FF"
    "test"    = "FFFF00"
  }
}
```

### 3. Keep `Count`-Based Resources

Leave the `count`-based resources in place for comparison.

### 4. Add Repository Resources Using `For_Each`

Add new repository resources using `for_each` to `main.tf`:

```hcl
# Repositories created with for_each
resource "github_repository" "repo_foreach" {
  for_each    = var.repositories
  name        = "repo-${each.key}"
  description = each.value
  visibility  = "public"
  auto_init   = true

  topics = ["terraform", "foreach", "example"]
}
```

### 5. Apply and Compare Repositories

Initialize and apply the configuration:

```bash
terraform init
terraform plan
terraform apply
```

Compare the difference between the `count`-based and `for_each`-based repositories in GitHub:
- Notice how the `for_each` repositories have meaningful names based on map keys
- Observe how the resources are referenced differently in the state file

To get a better look, use the `terraform state list` command to display the resources managed in state. See how the `for_each` have meaningful names, where the `count`-based resources are named based on the index.

> If you get the error `403 Resource not accessible by personal access token []`, make sure your token has sufficient permissions to your account. For `labels`, make sure you have write permissions to `Issues`.

### 6. Add Branch Protection Rules Using `For_Each`

Create a cross-product of repositories and branch patterns with nested `for_each`:

```hcl
# Branch protection rules created with for_each
resource "github_branch_protection" "protection_api" {
  for_each      = var.branch_patterns
  repository_id = github_repository.repo_foreach["api"].node_id
  pattern       = each.key

  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true
}

resource "github_branch_protection" "protection_web" {
  for_each      = var.branch_patterns
  repository_id = github_repository.repo_foreach["web"].node_id
  pattern       = each.key

  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = true
}
```

Apply the configuration:

```bash
terraform plan
terraform apply
```

### 7. Add Issue Label Resources Using `For_Each`

Add labels to the "api" and "web" repositories:

```hcl
# Issue labels for API repository
resource "github_issue_label" "label_api" {
  for_each    = var.label_config
  repository  = github_repository.repo_foreach["api"].name
  name        = each.key
  color       = each.value
  description = "${each.key} label for API repository"
}

# Issue labels for Web repository
resource "github_issue_label" "label_web" {
  for_each    = var.label_config
  repository  = github_repository.repo_foreach["web"].name
  name        = each.key
  color       = each.value
  description = "${each.key} label for Web repository"
}
```

Apply the configuration:

```bash
terraform plan
terraform apply
```

Notice how the `key` here is the name of the label and the `value` is the color of the label (found in the GitHub UI). This combination is determined by the variable `var.label_config` since that's what these resource blocks are iterating over using `for_each`.

### 8. Create Repository Files Using `For_Each`

Add a new map variable for repository files:

```hcl
variable "repo_files" {
  description = "Map of repository files"
  type        = map(string)
  default = {
    "README.md"        = "# Repository README\nThis is a sample repository."
    "CONTRIBUTING.md"  = "# Contributing Guidelines\nHow to contribute to this project."
    "LICENSE"          = "MIT License\nCopyright (c) 2023"
  }
}
```

Add repository files for the API repository:

```hcl
# Repository files created with for_each
resource "github_repository_file" "api_files" {
  for_each            = var.repo_files
  repository          = github_repository.repo_foreach["api"].name
  branch              = "main"
  file                = each.key
  content             = each.value
  commit_message      = "Add ${each.key}"
  commit_author       = "Terraform"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}
```

Apply the configuration:

```bash
terraform plan
terraform apply
```

### 9. Create Outputs for For_Each Resources

Create an `outputs.tf` file to reference for_each-based resources:

```hcl
output "repo_count_urls" {
  description = "URLs of count-based repositories"
  value       = github_repository.repo_count
}

output "repo_foreach_urls" {
  description = "URLs of for_each-based repositories"
  value       = github_repository.repo_foreach
}

output "branch_protection_api" {
  description = "Branch protection rules for API repository"
  value       = github_repository_file.api_files
}

output "label_api" {
  description = "Labels for API repository"
  value       = github_issue_label.label_api
}
```

Apply to see the outputs:

```bash
terraform apply
```

### 10. Experiment by Modifying Resources

Let's demonstrate the advantage of for_each when removing or renaming resources:

1. Modify the `repositories` variable to remove **one** repository:

```hcl
variable "repositories" {
  description = "Map of repository configurations"
  type        = map(string)
  default = {
    "api" = "API service repository"
    "web" = "Web frontend repository"
    # Removed "database" repository
  }
}
```

2. Also modify the `repo_names` list to remove an element:

```hcl
variable "repo_names" {
  description = "Names for repositories"
  type        = list(string)
  default     = ["repo-1", "repo-2"] # <-- Removed the third element
}
```

Apply the changes and observe the differences:

```bash
terraform plan
```

Notice how:
- With count, removing an element shifts all indexes, potentially recreating resources
- With for_each, only the specific "database" repository is removed, leaving others untouched

### 11. Add a New Resource to Existing Map

Add a new entry to the `label_config` map:

```hcl
variable "label_config" {
  description = "Map of label configurations"
  type        = map(string)
  default = {
    "bug"     = "FF0000"
    "feature" = "00FF00"
    "docs"    = "0000FF"
    "test"    = "FFFF00"
    "security" = "FF00FF" # <-- Added new entry
  }
}
```

Apply the changes:

```bash
terraform plan
terraform apply
```

Notice how only the new labels are added without affecting existing ones.

### 12. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Understanding `For_Each`

Let's examine how `for_each` improves your Terraform configurations:

### For_Each vs Count
- **For_Each**: Resources are indexed by key (string) instead of numeric index
- **Count**: Resources are indexed by position (0, 1, 2, ...)

### For_Each Advantages
- Resources maintain stable identity when items are added or removed
- Keys provide meaningful naming in state and GitHub
- More expressive and clear configuration
- Better handles non-uniform resource configurations

### For_Each Usage
- Can use a map with string keys
- With a basic map of strings: `for_each = var.repositories`
- With a map of colors: `for_each = var.label_config`

### Resource References
- Referencing a specific resource: `github_repository.repo_foreach["api"]`
- Referencing a value from a specific resource: `github_repository.repo_foreach["api"].name`
- Outputting all resources: `github_repository.repo_foreach`

## Additional Exercises

1. Create multiple teams using for_each
2. Add repository collaborators for each repository
3. Create different webhook configurations for each repository
4. Try creating repository deploy keys with for_each

## Common Issues and Solutions

1. **Invalid for_each Value**
   - For_each value must be a map or set of strings
   - Map values must be known at plan time

2. **Key Type Errors**
   - For_each keys must be strings
   - Numeric keys in maps should be quoted

3. **Resource References**
   - Access for_each resources with square brackets and the key
   - Don't use numeric indexes (like with count)