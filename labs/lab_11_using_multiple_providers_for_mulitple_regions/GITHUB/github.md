# LAB-11-GH: GitHub Multi-Provider Authentication Lab
## Overview
This lab demonstrates how to use multiple provider blocks in Terraform with different authentication tokens to manage GitHub resources. You'll create two GitHub provider configurations with different permission levels - one with full repository access and one with read-only access - to understand how provider authentication impacts resource creation.

[![Lab 11](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed
- A GitHub account
- Two GitHub personal access tokens (one with full repo access, one read-only)
- Basic understanding of Terraform and GitHub concepts

## How to Use This Hands-On Lab
1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions to create the required tokens and complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time
15 minutes

> Note: for GitHub, this lab was a little harder to create because most people may not have access to multiple accounts nor organizations. So I simplified it to use a single account but still have you go through the exercises using mulitple tokens so you can see how this feature would work.

## Creating GitHub Tokens
For this lab, you'll need to create two GitHub personal access tokens:

1. **Full Access Token**: With complete repository permissions
2. **Read-Only Token**: With only read access to repositories

### Creating a Full Access Token:
1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token" → "Generate new token (classic)"
3. Name it "terraform-full-access"
4. Set expiration to 7 days
5. Select the following permissions:
   - `repo` (all repo permissions)
6. Click "Generate token" and copy the token

### Creating a Read-Only Token:
1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token" → "Generate new token (classic)" 
3. Name it "terraform-read-only"
4. Set expiration to 7 days
5. Select only these permissions:
   - `repo:status`
   - `public_repo`
   - `repo_deployment`
6. Click "Generate token" and copy the token

## Lab Steps

### 1. Set Up Environment Variables
Set your GitHub tokens as environment variables on the command line:

```bash
export TF_VAR_github_token_full="your-full-access-token"
export TF_VAR_github_token_readonly="your-read-only-token"
```

### 2. Create Provider Configuration
Update the file named `providers.tf` with the following content:

```hcl
# Provider that uses full access token
provider "github" {
  alias = "full_access"
  token = var.github_token_full
}

# Provider that uses read-only token
provider "github" {
  alias = "read_only"
  token = var.github_token_readonly
}
```

### 3. Create Variables File
Add the following variable declarations to `variables.tf`:

```hcl
variable "github_token_full" {
  description = "GitHub Personal Access Token with full repository access"
  type        = string
  sensitive   = true
}

variable "github_token_readonly" {
  description = "GitHub Personal Access Token with read-only access"
  type        = string
  sensitive   = true
}

variable "repo_name" {
  description = "Name of the GitHub repository to be created"
  type        = string
  default     = "terraform-repo-for-alias-demo"
}
```

### 4. Create Main Configuration
Add the following resource blocks to the `main.tf` file to build our GitHub resources:

```hcl
# Repository created with the full access provider
resource "github_repository" "full_access_repo" {
  name        = var.repo_name
  description = "Repository created with full access token"
  visibility  = "public"
  auto_init   = true
}

# Add a README file using the full access provider
resource "github_repository_file" "readme" {
  repository        = github_repository.full_access_repo.name
  branch            = "main"
  file              = "README.md"
  content           = "# Provider Demo Repo\n\nThis repos demonstrates Terraform provider configs with different auth tokens."
  commit_message    = "Add README"
  commit_author     = "Terraform"
  commit_email      = "terraform@example.com"
  overwrite_on_create = true
}
```

For each `resource` blocks above, add the following argument to tell Terraform what provider to use - I usually put this as the first argument so it's easy to quickly see what providers my different resources are using.

```hcl
  provider = github.full_access
```

### 5. Initialize Terraform and Create First Resources
Run the following commands:

```bash
terraform fmt
terraform init
terraform apply -auto-approve
```

This will create a repository using the full access token.

> Reminder: If you get the error `403 Resource not accessible by personal access token []`, make sure your token has sufficient permissions to your account. For `github_repository_file`, make sure you have write permissions to `Contents`.

### 6. Try Using the Read-Only Token

Now, attempt to create a branch using the read-only token. This will fail due to permission limitations.

Add the following to your `main.tf` file:

```hcl
resource "github_branch" "read_only_branch" {
  provider      = github.read_only
  repository    = github_repository.full_access_repo.name
  branch        = "read-only-branch"
  source_branch = "main"
}
```

### 7. Apply the Changes and Observe Failure
Run the apply command again:

```bash
terraform apply
```

This should fail with an error message indicating insufficient permissions when using the read-only token.

### 8. Try Reading Repository Information
Update the failed resource to something that should work with read-only access. Replace the branch resource with a data block:

```hcl
# Remove the failed branch resource created above

# This will work with the read-only token
data "github_repository" "read_only_repo" {
  provider = github.read_only
  name     = github_repository.full_access_repo.name
}
```

Add an `outputs.tf` file and add the following output block to output information from the data block:

```hcl
output "repo_details_read_only" {
  description = "Repository details retrieved with read-only token"
  value = {
    name        = data.github_repository.read_only_repo.name
    description = data.github_repository.read_only_repo.description
    url         = data.github_repository.read_only_repo.html_url
  }
}
```

### 9. Apply Again to See It Work
Run:

```bash
terraform apply
```

Now you should see both outputs work successfully, as reading repository information is allowed with the read-only token.

### 10. Experiment with Swapping Tokens
As a final experiment, try changing your `main.tf` to use the read-only token for creating resources:

```hcl
resource "github_repository" "full_access_repo" {
  provider    = github.read_only                    # <--- change the value to github.read_only
  name        = var.repo_name
  description = "Repository created with full access token"
  visibility  = "public"
  auto_init   = true
}
```

### 11. Apply and Observe Failure
Run:

```bash
terraform apply
```

This should fail, demonstrating that the read-only token doesn't have permission to create repositories. Note that since the repository was already created, you might need to run a `terraform destroy` with the `github.full_access` provider first to see the error.

### 13. Clean Up Resources
When you're done, clean up all resources:

```bash
terraform destroy
```

## Understanding Provider Authentication
This lab demonstrates several important concepts:

1. **Different Authentication per Provider**: Each provider alias can use its own authentication credentials
2. **Permission Levels**: Different tokens with different permission scopes affect what operations can be performed
3. **Provider Selection**: Resources specify which provider to use with the `provider = github.<alias>` syntax
4. **Operation Types**: Some operations (like reading) work with limited permissions, while others (like creating resources) require higher permission levels

## Real-World Applications
In real-world scenarios, you might use multiple provider configurations with different authentication levels to:

1. Implement least-privilege access for different types of resources
2. Separate read-only operations from write operations
3. Use different service accounts for different environments (dev, staging, prod)
4. Allow certain CI/CD pipelines to only read but not modify infrastructure

This pattern helps implement security best practices by ensuring each component has only the permissions it needs.