# LAB-14-GH: Using Terraform Registry Modules with GitHub

## Overview
In this lab, you will learn how to use modules from the Terraform Registry to create GitHub infrastructure more efficiently. You'll use two different modules, with one module using the output from another. You'll also call the same module multiple times with different parameters to create similar but unique resources. The lab uses GitHub free resources to ensure no costs are incurred.

[![Lab 14](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml)

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
25 minutes

## Initial Configuration Files

 - `providers.tf`
 - `variables.tf`

## Lab Steps

### 1. Configure GitHub Credentials

Set up your GitHub personal access token:

```bash
export GITHUB_TOKEN="your_personal_access_token"
```

### 2. Use the GitHub Repository Module from Terraform Registry

Add the following to the `main.tf` file and use the GitHub Repository module:

```hcl
module "repository" {
  source  = "mineiros-io/repository/github"
  version = "0.18.0"

  name        = "${var.environment}-app"
  description = "Application repository for ${var.environment} environment"
  topics      = ["terraform", "application", var.environment]
  visibility  = var.repository_visibility
  archived    = false
}
```

### 3. Use the GitHub Branch Protection with Repository Output

Add the GitHub Branch Protection module, using the repository output from the first module:

```hcl
module "default-branch-protection" {
  source  = "masterborn/default-branch-protection/github"
  version = "1.1.0"

  repository_name = split("/", module.repository.full_name)[1]
}
```

### 4. Create Multiple Repositories Using For_Each

Call the repository module again with different parameters to create another repo:

```hcl
module "user-repositories" {
  source  = "mineiros-io/repository/github"
  version = "0.18.0"

  for_each    = var.user_repos
  name        = "${each.value}-${var.environment}-app"
  description = "Application repository for ${var.environment} environment"
  topics      = ["terraform", "application", var.environment]
  visibility  = var.repository_visibility
  archived    = false
}
```

### 5. Configure Branch Protection for the User's Repository

Set up branch protection for the second repository:

```hcl
module "user-default-branch-protection" {
  source  = "masterborn/default-branch-protection/github"
  version = "1.1.0"

  for_each = var.user_repos
  repository_name = split("/", module.user-repositories[each.key].full_name)[1]
}
```

### 6. Initialize and Apply

Initialize and apply the configuration:

```bash
terraform init
```

> Notice how Terraform downloads the modules locally so it can now use them to create our resources.

Run a plan and apply:

```bash
terraform plan
terraform apply
```

Notice how Terraform:
- Downloads the modules from the Terraform Registry
- Creates repositories using the GitHub repository module
- Applies branch protection to each repository
- Creates multiple repositories using for_each

### 7. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Understanding Module Usage

Let's examine the key aspects of using modules from the Terraform Registry:

### Module Sources
The `source` attribute specifies where to find the module:
```hcl
source = "mineiros-io/repository/github"
```
This format refers to modules in the public Terraform Registry.

### Module Versioning
The `version = "1.1.0"` portion pins the module to a specific version when using Git sources.
This ensures consistent behavior even if the module is updated.

### Module Inputs
Each module accepts input variables that control its behavior:
```hcl
name = "${var.environment}-app"
```

### Module Outputs
Modules provide outputs that can be used by other resources:
```hcl
repository_name = module.repository.repository_name
```
Here, the repository name output from the first module is used as an input for the second module.

### Multiple Module Instances
The same module can be called multiple times with different parameters:
```hcl
module "repository" {
  name = "${var.environment}-app"
  ...
}

module "repository_xyz" {
  name = "${var.environment}-app-xyz-repo"
  ...
}
```

### Using For_Each with Modules
Modules can be instantiated multiple times using for_each:
```hcl
module "multiple_repositories" {
  for_each = var.additional_repositories
  name = "${var.environment}-${each.key}"
  ...
}
```
This creates one module instance for each element in the map, with each instance receiving different input values.

## Additional Resources

- [Terraform Registry](https://registry.terraform.io/)
- [HappyPathway GitHub Repository Module](https://registry.terraform.io/modules/HappyPathway/repo/github/latest)
- [Masterborn GitHub Branch Protection Module](https://github.com/masterborn/terraform-github-default-branch-protection)