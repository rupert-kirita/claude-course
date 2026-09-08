# LAB-19-GITHUB: Importing an Existing Resource

## Overview

In this lab, you will bring existing, unmanaged GitHub resources under Terraform management using both the `terraform import` CLI command and the `import` block. You'll start with live resources and an **empty state file**, import each resource, and prove the configuration matches with a clean plan.

This lab picks up exactly where [Lab 18](../../lab_18_refactor_state_with_moved_and_removed_blocks/GITHUB/github.md) left off: the repository, repository file, and issue label you orphaned with `removed` blocks still exist in GitHub, but Terraform no longer knows about them. By the end of this lab they are back under Terraform management — and a final `terraform destroy` cleans up everything Lab 18 left behind. All resources in this lab are free on the GitHub Free plan.

[![Lab 19](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml)

## Prerequisites

- Terraform installed (v1.12.2+)
- GitHub account
- GitHub personal access token with `repo` permissions
- The orphaned resources from Lab 18 (`lab-refactor-repo`, `config/app.txt`, `lab-label`) still in place — see the note in Step 1 if you skipped Lab 18

Note: export your token before you begin so the GitHub provider can authenticate:

```bash
export GITHUB_TOKEN="<your_github_token>"
```

> To complete the Clean Up section, your token also needs permission to delete repositories (the `delete_repo` scope on a classic token, or **Administration: Read and write** on a fine-grained token).

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).
2. Once the Codespace is running, open the integrated terminal.
3. Change into this lab's directory: `cd labs/lab_19_import_a_resource/GITHUB`
4. Follow the instructions below to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time

30 minutes

## Initial Configuration Files

This lab ships with three starter files in the working directory: `providers.tf`, `variables.tf`, and `main.tf`. Unlike previous labs, `main.tf` starts out empty — the resources already exist in GitHub, and your job is to write the configuration that matches them.

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
  description = "Name of the existing lab repository"
  type        = string
  default     = "lab-refactor-repo"
}

variable "repository_description" {
  description = "Description of the existing lab repository"
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

variable "app_label_name" {
  description = "Name of the existing application issue label"
  type        = string
  default     = "lab-label"
}

variable "app_label_color" {
  description = "Color of the application issue label (hex, no #)"
  type        = string
  default     = "0e8a16"
}
```

> The defaults match the resources exactly as Lab 18 created them — change a default and the post-import plan will no longer come back clean.

### main.tf

```hcl
# This file starts intentionally empty.
#
# The repository, repository file, and issue label created in Lab 18
# still exist in GitHub, but they are no longer tracked in Terraform
# state. During this lab you will add resource and import blocks here
# to bring each one back under Terraform management.
```

## Lab Steps

### 1. Confirm the Orphaned Resources Still Exist

Lab 18 ended with `removed` blocks that took the repository, repository file, and issue label out of Terraform state while leaving them live in GitHub.

Open GitHub in your browser and confirm all three: the `lab-refactor-repo` repository exists, the `config/app.txt` file is present on its `main` branch, and the `lab-label` label still exists. For the label, browse directly to `https://github.com/<your-username>/lab-refactor-repo/labels` (the repository was created without the Issues tab enabled, so the labels page is not linked from the navigation).

GitHub resources import by human-readable string identifiers built from names — no ID lookup required. These are the same identifiers you recorded in Lab 18 Step 8:

- Repository: `lab-refactor-repo`
- Repository file: `lab-refactor-repo/config/app.txt:main`
- Issue label: `lab-refactor-repo:lab-label`

> **Skipped Lab 18?** Create the resources manually in GitHub first: a public repository named `lab-refactor-repo` with the description `Lab repository for state refactoring` (initialize it with a README), a file at `config/app.txt` on the `main` branch containing exactly `Managed by Terraform`, and an issue label named `lab-label` with color `0e8a16`. Manually created resources will not match this guide's configuration exactly (the web UI enables Issues and Wikis, and your file's commit metadata will differ), so wherever this guide expects `No changes.`, adjust your configuration until the plan matches what actually exists.

### 2. Initialize and Confirm the State Is Empty

Initialize the working directory, then list the resources Terraform is managing:

```bash
terraform init
terraform state list
```

The `terraform state list` command returns nothing. Real resources exist, but the state file knows about none of them.

### 3. Write a Resource Block for the Repository

Start with the `terraform import` CLI command. As a reminder, it does not write configuration for you, and it refuses to run until a resource block for the target address exists — so the resource block comes first.

Add the following resource block to `main.tf`, describing the repository exactly as it exists in GitHub:

```hcl
resource "github_repository" "main" {
  name        = var.repository_name
  description = var.repository_description
  visibility  = var.repository_visibility
}
```

> Lab 18 created this repository with `auto_init = true`, but that argument only matters at creation time, so it is left out of the import configuration.

### 4. Import the Repository with the `terraform import` Command

Run the import command. The import ID for a repository is simply its name:

```bash
terraform import github_repository.main lab-refactor-repo
```

You should see output similar to:

```
github_repository.main: Importing from ID "lab-refactor-repo"...
github_repository.main: Import prepared!
  Prepared github_repository for import
github_repository.main: Refreshing state... [id=lab-refactor-repo]

Import successful!

The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.
```

Confirm the repository is back in state:

```bash
terraform state list
```

You should see exactly one address:

```
github_repository.main
```

### 5. Verify the Configuration Matches Reality

Run a plan:

```bash
terraform plan
```

You should see:

```
No changes. Your infrastructure matches the configuration.
```

A clean plan is the proof the import worked.

> If the plan shows changes, your configuration does not match the real resource. Fix the **configuration**, not the resource, and plan again until it is clean.

### 6. Import the Repository File with an `import` Block

Next, use the `import` block. Instead of running a command per resource, you declare the import in configuration and let a single apply handle several imports at once.

Add the following to `main.tf`. The import ID for a repository file combines the repository, the file path, and the branch:

```hcl
import {
  to = github_repository_file.config
  id = "lab-refactor-repo/config/app.txt:main"
}

resource "github_repository_file" "config" {
  repository     = github_repository.main.name
  branch         = "main"
  file           = var.config_file_path
  content        = var.config_file_content
  commit_message = "Add app config"
  commit_author  = "Terraform User"
  commit_email   = "terraform@example.com"
}
```

> Like `auto_init` in Step 3, the `overwrite_on_create` argument Lab 18 used only affects creation and is left out here.

Run a plan:

```bash
terraform plan
```

The plan now includes an import operation:

```
Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
```

Nothing has happened yet, because import blocks perform the import at **apply** time. Don't apply yet — first, add the issue label so a single apply imports both resources.

### 7. Generate the Issue Label Configuration Automatically

For the repository file, you hand-wrote the resource block. For the issue label, let Terraform write it for you. Add **only** an import block to `main.tf` — no resource block this time:

```hcl
import {
  to = github_issue_label.main
  id = "lab-refactor-repo:lab-label"
}
```

Now generate configuration for any import target that has no matching resource block:

```bash
terraform plan -generate-config-out=generated.tf
```

Open `generated.tf` and review it. Every value is a hardcoded literal (the `repository` is the raw string `"lab-refactor-repo"` instead of a reference to `github_repository.main.name`), and attributes you never set may appear. Generated blocks are not always perfect, so review every line. Move the resource block into `main.tf` and clean it up so it looks like this:

```hcl
resource "github_issue_label" "main" {
  repository = github_repository.main.name
  name       = var.app_label_name
  color      = var.app_label_color
}
```

Delete the now-empty `generated.tf` file, then run a plan to confirm both pending imports are recognized:

```bash
terraform plan
```

```
Plan: 2 to import, 0 to add, 0 to change, 0 to destroy.
```

### 8. Apply to Complete the Imports

Run the apply:

```bash
terraform apply -auto-approve
```

Terraform imports both resources in one operation:

```
Apply complete! Resources: 2 imported, 0 added, 0 changed, 0 destroyed.
```

### 9. Verify Everything Is Under Management

List the state one more time:

```bash
terraform state list
```

You should see all three resources:

```
github_issue_label.main
github_repository.main
github_repository_file.config
```

Run a final plan and confirm it comes back clean:

```bash
terraform plan
```

```
No changes. Your infrastructure matches the configuration.
```

Finally, **delete the two `import` blocks** from `main.tf`. Like `moved` and `removed` blocks, they describe a one-time operation and can be removed once applied.

## Clean Up

Now that Terraform manages the resources again, `terraform destroy` works.

Destroy the resources:

```bash
terraform destroy -auto-approve
```

You should see:

```
Destroy complete! Resources: 3 destroyed.
```

This removes the repository Lab 18 intentionally left behind.

> If the destroy fails on the repository with a `403 Must have admin rights` or `delete_repo` error, your token lacks repository deletion permission. Grant the scope described in the Prerequisites and run `terraform destroy` again — or delete the repository manually in GitHub under **Settings → Danger Zone**.

## Key Concepts

### Importing Changes State, Never Infrastructure

- Both methods bind a resource address to a real object — the object itself is untouched.
- Terraform does not reconcile your configuration on import; it simply starts comparing the two. A clean plan is the proof the import worked.

### Import ID Formats Are Provider-Specific

- GitHub uses name-based identifiers (`repo`, `repo/path:branch`, `repo:label`) instead of opaque IDs like AWS's `vpc-...` or Azure's ARM paths. The **Import** section of each resource's provider documentation shows the exact format.

### Two Methods, One Goal

| | `terraform import` (CLI) | `import` block (config-driven) |
| --- | --- | --- |
| Style | Imperative, one command per resource | Declarative, lives in your configuration |
| Configuration | You must hand-write the resource block first | Optional generation via `-generate-config-out` |
| Scale | One resource at a time | Many resources in a single apply |
| Reviewability | Runs from your terminal, leaves no trace in the repo | Visible in version control and code review |

### Generated Configuration Needs Cleanup

- `-generate-config-out` hardcodes every value as a literal and includes attributes you never set — treat it as a draft: replace literals with references and variables, prune, and review before applying. The GitHub provider in particular can produce blocks that need hand-editing.
- Create-time arguments like `auto_init` and `overwrite_on_create` do not belong in import configuration, and like `moved` and `removed` blocks, `import` blocks can be deleted once applied.

## Additional Challenge

1. Recreate the `outputs.tf` file from Lab 18 Step 8 (repository name, full name, file path, and label name) and confirm the output values match the identifiers you used to import — proof that these are the very same resources.
2. Introduce deliberate drift before the final destroy: change the issue label's color in your configuration to `d73a4a`, run `terraform plan`, and observe how Terraform proposes an in-place update. Revert the change and confirm the plan is clean again.
3. Inspect an imported resource in detail with `terraform state show github_repository.main` and compare each attribute against your resource block. How many attributes does the state track that your configuration never mentions?
