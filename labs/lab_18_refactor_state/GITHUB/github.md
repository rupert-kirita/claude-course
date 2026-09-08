# LAB-18-GITHUB: Refactoring State with the `moved` and `removed` Blocks

## Overview

In this lab, you will refactor your Terraform configuration **without destroying and recreating live infrastructure**. You'll build a small set of GitHub resources, then see firsthand what happens when you rename a resource *without* a `moved` block. You'll fix the rename properly with a `moved` block, practice moving a resource into and back out of a child module, and then use `removed` blocks in both of their modes: first to destroy a resource you no longer need, and then to hand ownership of the remaining resources off so they stay in place while Terraform stops managing them.

The resources you orphan at the end of this lab are intentionally left in place so they can be imported back under Terraform management in a future lab. Delete them yourself when you're done (see [Clean Up](#clean-up)). All resources in this lab (a public repository, a repository file, and issue labels) are free on the GitHub Free plan.

[![Lab 18](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml)

## Prerequisites

- Terraform installed (v1.12.2+)
- GitHub account
- GitHub personal access token with `repo` permissions

Note: export your token before you begin so the GitHub provider can authenticate:

```bash
export GITHUB_TOKEN="<your_github_token>"
```

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).
2. Once the Codespace is running, open the integrated terminal.
3. Change into this lab's directory: `cd labs/lab_18_refactor_state_with_moved_and_removed_blocks/GITHUB`
4. Follow the instructions below to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time

40 minutes

## Initial Configuration Files

This lab ships with three starter files in the working directory: `providers.tf`, `variables.tf`, and `main.tf`. You will create an `outputs.tf` file later, in Step 8.

### providers.tf

```hcl
terraform {
  required_version = ">= 1.12.2"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {}
```

### variables.tf

```hcl
variable "repository_name" {
  description = "Name of the lab repository"
  type        = string
  default     = "lab-refactor-repo"
}

variable "repository_description" {
  description = "Description for the lab repository"
  type        = string
  default     = "Lab repository for state refactoring"
}

variable "repository_visibility" {
  description = "Visibility of the repository (public or private)"
  type        = string
  default     = "public"
}

variable "config_file_path" {
  description = "Path of the managed file within the repository"
  type        = string
  default     = "config/app.txt"
}

variable "config_file_content" {
  description = "Contents of the managed file"
  type        = string
  default     = "Managed by Terraform"
}

variable "legacy_label_name" {
  description = "Name of the legacy issue label"
  type        = string
  default     = "legacy"
}

variable "legacy_label_color" {
  description = "Color of the legacy issue label (hex, no #)"
  type        = string
  default     = "d73a4a"
}

variable "app_label_name" {
  description = "Name of the application issue label"
  type        = string
  default     = "lab-label"
}

variable "app_label_color" {
  description = "Color of the application issue label (hex, no #)"
  type        = string
  default     = "0e8a16"
}
```

### main.tf

```hcl
# GitHub Repository
resource "github_repository" "main" {
  name        = var.repository_name
  description = var.repository_description
  visibility  = var.repository_visibility
  auto_init   = true
}

# Repository File
resource "github_repository_file" "config" {
  repository          = github_repository.main.name
  branch              = "main"
  file                = var.config_file_path
  content             = var.config_file_content
  commit_message      = "Add app config"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}

# Legacy Issue Label
resource "github_issue_label" "legacy" {
  repository = github_repository.main.name
  name       = var.legacy_label_name
  color      = var.legacy_label_color
}

# Application Issue Label
resource "github_issue_label" "web" {
  repository = github_repository.main.name
  name       = var.app_label_name
  color      = var.app_label_color
}
```

## Lab Steps

### 1. Review and Deploy the Starting Configuration

Initialize the working directory, review the plan, then apply to create the four resources:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

Terraform creates the repository, the repository file, and the two issue labels.

### 2. Confirm the Resources Are Tracked in State

List the resources Terraform is managing:

```bash
terraform state list
```

You should see the following four addresses:

```
github_issue_label.legacy
github_issue_label.web
github_repository.main
github_repository_file.config
```

### 3. See What a Rename Does WITHOUT a `moved` Block

Suppose you want to rename the issue label resource from `web` to `app` to better reflect its purpose. Before reaching for a `moved` block, see how Terraform interprets a plain rename.

In `main.tf`, change the issue label resource label from `web` to `app`. Leave the `name` argument set to `var.app_label_name`:

```hcl
resource "github_issue_label" "app" {
  repository = github_repository.main.name
  name       = var.app_label_name
  color      = var.app_label_color
}
```

Run a plan, but **DO NOT apply**:

```bash
terraform plan
```

Look closely at the output. Terraform has no idea these are the same resource. It sees `github_issue_label.web` vanish from the configuration and a brand-new `github_issue_label.app` appear, so it plans to destroy one and create the other:

```
Plan: 1 to add, 0 to change, 1 to destroy.
```

On a production system this means the label is deleted and recreated, dropping it from every issue it was attached to. In this specific case the apply could even fail partway through, because an issue label name must be unique within a repository, and the new label uses the same name as the label Terraform is destroying.

> Do not apply this plan. In the next step you'll tell Terraform what you actually meant.

### 4. Rename the Resource Properly with a `moved` Block

A `moved` block tells Terraform that the resource at a new address is the *same object* as the one at the old address, so it updates the state entry instead of destroying and recreating the resource.

Leave the renamed resource block in place and add the following `moved` block to `main.tf`:

```hcl
moved {
  from = github_issue_label.web
  to   = github_issue_label.app
}
```

Run a plan and confirm Terraform now reports a move with zero resources to add, change, or destroy:

```bash
terraform plan
```

You should see a line similar to:

```
github_issue_label.web has moved to github_issue_label.app
```

Apply the change, then confirm the resource now appears under its new address:

```bash
terraform apply -auto-approve
terraform state list
```

Once the move is applied, **delete the `moved` block** from `main.tf`. That's safe here because you're the only user of this configuration and you've already applied the move. In a shared module, you'd keep the `moved` block in place so other users get the same upgrade path.

### 5. Move the Repository File Into a Child Module

Renames aren't the only refactor a `moved` block can handle — it can also relocate a resource into a module. Suppose your team decides all repository files should live in a reusable module.

Create the module directory:

```bash
mkdir -p modules/repofiles
```

Create a new file at `modules/repofiles/main.tf` with the following content:

```hcl
variable "repository" {
  description = "Name of the repository where the file will be managed"
  type        = string
}

variable "config_file_path" {
  description = "Path of the managed file within the repository"
  type        = string
}

variable "config_file_content" {
  description = "Contents of the managed file"
  type        = string
}

resource "github_repository_file" "config" {
  repository          = var.repository
  branch              = "main"
  file                = var.config_file_path
  content             = var.config_file_content
  commit_message      = "Add app config"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}
```

In `main.tf`, delete the `github_repository_file.config` resource block and replace it with a module block and a `moved` block:

```hcl
module "repofiles" {
  source = "./modules/repofiles"

  repository          = github_repository.main.name
  config_file_path    = var.config_file_path
  config_file_content = var.config_file_content
}

moved {
  from = github_repository_file.config
  to   = module.repofiles.github_repository_file.config
}
```

Because you added a new module, initialize the working directory again so Terraform installs it:

```bash
terraform init
```

Run a plan and confirm Terraform reports a move with zero resources to add, change, or destroy:

```bash
terraform plan
```

You should see a line similar to:

```
github_repository_file.config has moved to module.repofiles.github_repository_file.config
```

Apply the change, then confirm the file now lives at a module address:

```bash
terraform apply -auto-approve
terraform state list
```

The file appears as `module.repofiles.github_repository_file.config`. The real file in GitHub was never touched.

### 6. Move the Repository File Back to the Root Module

Moves work in both directions. A future import lab expects these resources in a flat configuration, so move the file back to the root module before the handoff.

First, delete the `moved` block you added in Step 5 — it has been applied and has served its purpose.

In `main.tf`, delete the `module "repofiles"` block and restore the original file resource block:

```hcl
resource "github_repository_file" "config" {
  repository          = github_repository.main.name
  branch              = "main"
  file                = var.config_file_path
  content             = var.config_file_content
  commit_message      = "Add app config"
  commit_author       = "Terraform User"
  commit_email        = "terraform@example.com"
  overwrite_on_create = true
}
```

Add a `moved` block pointing in the opposite direction:

```hcl
moved {
  from = module.repofiles.github_repository_file.config
  to   = github_repository_file.config
}
```

Run a plan, confirm the move with zero changes, and apply:

```bash
terraform plan
terraform apply -auto-approve
terraform state list
```

Delete this `moved` block as well, and remove the now-unused module directory:

```bash
rm -r modules
```

### 7. Destroy the Legacy Label with a `removed` Block

A `removed` block tells Terraform to stop managing a resource. It has two modes, and this step demonstrates the default one: remove the resource from state **AND** destroy the real infrastructure.

Your configuration no longer needs the legacy issue label, so retire it the configuration-driven way. In `main.tf`, delete the `github_issue_label.legacy` resource block and add the following `removed` block in its place:

```hcl
removed {
  from = github_issue_label.legacy

  lifecycle {
    destroy = true
  }
}
```

The `destroy` argument is set to `true` here for clarity, but `true` is the default. Run a plan and note the difference from every plan so far in this lab — this one destroys a real object:

```bash
terraform plan
```

You should see:

```
Plan: 0 to add, 0 to change, 1 to destroy.
```

Apply the change, then confirm the label is gone from state:

```bash
terraform apply -auto-approve
terraform state list
```

You should see only three addresses remaining. If you check the repository's **Labels** page in GitHub, the `legacy` label has been deleted. Keep this result in mind — in Step 9 you'll use the same block type with one argument flipped to get the opposite behavior.

Once the apply completes, **delete the `removed` block** from `main.tf`.

### 8. Add Output Blocks to Retrieve the Resource Identifiers

Before you orphan the remaining resources, capture the identifiers you'll need to import them back in a future lab. GitHub resources are imported by string identifiers rather than by a numeric ID.

Create a new `outputs.tf` file with the following content:

```hcl
output "repository_name" {
  description = "Name of the repository"
  value       = github_repository.main.name
}

output "repository_full_name" {
  description = "Full name (owner/repo) of the repository"
  value       = github_repository.main.full_name
}

output "config_file_path" {
  description = "Path of the managed file"
  value       = github_repository_file.config.file
}

output "issue_label_name" {
  description = "Name of the application issue label"
  value       = github_issue_label.app.name
}
```

Run a plan and apply to render the outputs:

```bash
terraform plan
terraform apply -auto-approve
```

In the terminal you'll see the output values. **Write these down somewhere safe** — a future import lab uses identifiers built from them:

```
- repository:       lab-refactor-repo
- repository file:  lab-refactor-repo/config/app.txt:main
- issue label:      lab-refactor-repo:lab-label
```

### 9. Orphan the Remaining Resources with `removed` Blocks

In Step 7, a `removed` block destroyed the legacy label. Setting the `lifecycle` `destroy` argument to `false` changes the behavior entirely: Terraform forgets the resource but leaves it untouched in GitHub.

Delete all three resource blocks from `main.tf`. Also **delete the `outputs.tf` file**, because its outputs reference the resources you're about to remove and would cause an error once those resources leave the configuration. You already recorded the identifiers in Step 8.

Add the following three `removed` blocks to `main.tf` in place of the deleted resource blocks:

```hcl
removed {
  from = github_repository.main

  lifecycle {
    destroy = false
  }
}

removed {
  from = github_repository_file.config

  lifecycle {
    destroy = false
  }
}

removed {
  from = github_issue_label.app

  lifecycle {
    destroy = false
  }
}
```

Run a plan and confirm Terraform reports the resources will be removed from state with zero resources to destroy:

```bash
terraform plan
```

Compare this against the plan from Step 7. Same block type, but with `destroy = false` the plan shows nothing being destroyed.

Apply the change:

```bash
terraform apply -auto-approve
```

### 10. Verify State Is Empty and the Resources Still Exist

Confirm Terraform is no longer managing anything:

```bash
terraform state list
```

This command should return no results.

Use the GitHub website to confirm the resources still exist: open the `lab-refactor-repo` repository, confirm the `config/app.txt` file is present on the `main` branch, and open the **Labels** page to confirm the `lab-label` label is still there. They exist, but they're no longer under Terraform management — ready to be imported in a future lab.

## Clean Up

> `terraform destroy` will **not** remove these resources, because your state file is now empty. The legacy label was already destroyed by Terraform in Step 7, so only the repository and its contents remain.

Delete the repository on the GitHub website: open the `lab-refactor-repo` repository, go to **Settings**, scroll to the **Danger Zone**, and choose **Delete this repository**. Deleting the repository removes the `config/app.txt` file and the `lab-label` label in one action.

## Key Concepts

### The `moved` Block

- Records a change of address for a resource inside Terraform state.
- Lets you rename a resource, or move it into or out of a module, without Terraform interpreting the change as a destroy-and-recreate. **The real infrastructure is never touched.**
- Deleting a `moved` block after it's applied is safe for a private configuration, but is a breaking change for a shared module — consumers who haven't yet applied the move would see a destroy plan instead.

### The `removed` Block

- The configuration-driven replacement for the older `terraform state rm` command.
- Its behavior hinges on the `lifecycle` `destroy` argument:
  - **`destroy = true`** (the default) — removes the resource from state **and** destroys the real object.
  - **`destroy = false`** — Terraform forgets the resource but leaves the real object in place. This is how you hand a resource off between configurations, split a large state file, or transfer ownership between teams without downtime.

## Additional Challenge

1. Add a second repository file to the module and use one `moved` block per file to relocate both in a single refactor.
2. After orphaning the resources, run `terraform import` to bring the repository back under management using the identifier you captured in Step 8.
3. Add a second `moved` block that renames a resource *and* moves it into a module in the same apply, and confirm Terraform still reports zero changes.
