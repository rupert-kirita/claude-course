# LAB-13-GH: Using Basic Terraform Functions

## Overview
In this lab, you will learn how to use a few essential Terraform built-in functions: `min`, `max`, `join`, and `toset`. These functions help you manipulate values and create more flexible infrastructure configurations. The lab uses GitHub free resources to ensure no costs are incurred.

[![Lab 13](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml)

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
20 minutes

## Initial Configuration Files

 - `main.tf`
 - `providers.tf`
 - `variables.tf`

## Lab Steps

### 1. Configure GitHub Credentials

Set up your GitHub personal access token:

```bash
export GITHUB_TOKEN="your_personal_access_token"
```

### 2. Create Repositories with Join Function

Create a `main.tf` file with repository resources using the join function:

```hcl
# Use join function to create repository names
resource "github_repository" "main" {
  count       = min(3, length(var.repository_names))
  name        = join("-", [var.environment, var.repository_names[count.index]])
  description = "Repository for ${var.repository_names[count.index]}"
  visibility  = "public"
  auto_init   = true

  # This creates repos like "dev-api", "dev-web", etc. using the join function
}
```

### 3. View details of the `Min` Function for Repository Count

The code above already uses the `min` function to limit the number of repositories to create:
```hcl
count = min(3, length(var.repository_names))
```

This ensures that no more than `3` repositories are created, even if the variable contains more names.

### 4. Use Toset Function to Remove Duplicates

Create a tearepo for each unique members by converting the `var.team_members` **list** to a **set**:

```hcl
# Use toset function to remove duplicates from team members list
locals {
  unique_members = toset(var.team_members)
}

resource "github_repository" "user_repo" {
  for_each = local.unique_members

  name        = join("-", [var.environment, each.value])
  description = "Repo for ${each.value} to store code"
  visibility  = "public"
  auto_init   = true
}
```

### 5. Create Repository Topics with Join

Create repository topics by joining arrays:

```hcl
# Use join for topic descriptions
resource "github_repository_file" "readme" {
  count              = min(3, length(var.repository_names))
  repository         = github_repository.main[count.index].name
  branch             = "main"
  file               = "README.md"
  content            = <<-EOT
    # ${upper(var.repository_names[count.index])}
    
    This is the ${var.repository_names[count.index]} repository.
    
    Topics: ${join(", ", var.topics)}
  EOT
  commit_message     = "Add README with topics"
  commit_author      = "Terraform"
  commit_email       = "terraform@example.com"
  overwrite_on_create = true
}
```

### 6. Add Simple Outputs

Create an `outputs.tf` file with a few outputs:

```hcl
output "repository_urls" {
  description = "URLs of the created repositories"
  value       = github_repository.main[*].html_url
}

output "repository_count" {
  description = "Number of repositories created (using min function)"
  value       = min(3, length(var.repository_names))
}

output "unique_team_members" {
  description = "List of unique team members (using toset function)"
  value       = local.unique_members
}

output "user_repo_urls" {
  description = "A map of each user's repo URL"
  value = {
    for username, repo in github_repository.user_repo : username => repo.html_url
  }
}
```

### 7. Apply the Configuration

Initialize and apply the configuration:

```bash
terraform init
terraform plan
terraform apply
```

Observe how the functions work:
- `join` creates string values by combining elements
- `min` calculates the minimum value between two numbers
- `toset` converts a list to a set, removing duplicates

### 8. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Function Reference

### Join Function
The `join` function combines a list of strings with a specified delimiter.
```
join(separator, list)
```
Example: `join("-", ["dev", "api"])` produces `"dev-api"`

### Min Function
The `min` function returns the minimum value from a set of numbers.
```
min(number1, number2, ...)
```
Example: `min(3, 5)` produces `3`

### Toset Function
The `toset` function converts a list to a set, removing any duplicate elements.
```
toset(list)
```
Example: `toset(["user1", "user2", "user1"])` produces `["user1", "user2"]`