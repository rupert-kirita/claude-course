# LAB-17-GITHUB: Upgrading a Terraform Provider and Module

This lab demonstrates how to safely upgrade a Terraform provider and a community module to newer versions. You'll learn how to interpret version constraints, inspect the `.terraform.lock.hcl` file, and use `terraform init -upgrade` to pull in updated dependencies — all using free GitHub resources.

[![Lab 17](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/github_lab_validation.yml)

**Preview Mode:** Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed
- GitHub account
- GitHub personal access token with `repo` and `delete_repo` permissions

Note: A GitHub personal access token is required for this lab. The `delete_repo` scope is required so `terraform destroy` can remove the repositories at the end.

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
 - `outputs.tf`

## Lab Steps

### Task 1: Configure GitHub Credentials

Set up your GitHub personal access token as an environment variable. The provider reads this token automatically:

```bash
export GITHUB_TOKEN="your_personal_access_token"
```

> ⚠️ **Important:** The token must have permission to **create** and **delete** repositories. For a classic token, select the `repo` and `delete_repo` scopes. For a fine-grained token, grant **Administration: Read and write** on your account.

### Task 2: Create the Initial Configuration

In this task, you'll write a Terraform configuration that intentionally uses **older** pinned versions of both the GitHub provider and the popular `appvia/repository/github` community module.

Navigate to the lab working directory:

```bash
cd labs/lab_17_upgrade_a_provider_and_module/GITHUB
```

Add the following to the `providers.tf` file to declare the required provider with an older version constraint:

```hcl
terraform {
  required_version = ">= 1.12.2"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6.0"
    }
  }
}

provider "github" {
  owner = var.github_owner
  # The token is read from the GITHUB_TOKEN environment variable
}
```

Add the following to the `variables.tf` file:

```hcl
variable "github_owner" {
  description = "The GitHub user or organization where resources will be created"
  type        = string
}

variable "repository_name" {
  description = "Name of the repository managed by the community module"
  type        = string
  default     = "tf-upgrade-lab-module"
}

variable "standalone_repository_name" {
  description = "Name of the standalone repository managed directly"
  type        = string
  default     = "tf-upgrade-lab-standalone"
}
```

Add the following blocks to the `main.tf` file for a repository created by the community module (pinned to an older version) and a standalone repository resource:

```hcl
# Using a pinned older version of the community repository module
module "repo" {
  source  = "appvia/repository/github"
  version = "1.2.0"

  repository  = var.repository_name
  description = "Repository managed by the community module for the upgrade lab"
  visibility  = "public"
}

# Standalone GitHub repository (managed directly, not through the module)
resource "github_repository" "standalone" {
  name        = var.standalone_repository_name
  description = "Standalone repository for the Terraform upgrade lab"
  visibility  = "public"
  auto_init   = true
}
```

> ⚠️ **Important:** Repository names must be unique **within your account**. If you already have a repository with one of the default names, change the `default` value in `variables.tf` (or pass a `-var` at apply time).

Add the following to the `outputs.tf` file so you can verify what was created:

```hcl
output "module_repository_name" {
  description = "Name of the repository created by the community module"
  value       = module.repo.repository_name
}

output "module_repository_url" {
  description = "URL of the repository created by the community module"
  value       = module.repo.repository_html_url
}

output "standalone_repository_name" {
  description = "Name of the standalone repository"
  value       = github_repository.standalone.name
}

output "standalone_repository_url" {
  description = "URL of the standalone repository"
  value       = github_repository.standalone.html_url
}
```

---

### Task 3: Initialize and Deploy the Initial Infrastructure

Run `terraform init` to download the pinned provider and module versions:

```bash
terraform init
```

You should see output similar to the following, confirming which versions were installed:

```
Initializing the backend...
Initializing modules...
Downloading registry.terraform.io/appvia/repository/github 1.2.0 for repo...

Initializing provider plugins...
- Finding integrations/github versions matching "~> 6.6.0"...
- Installing integrations/github v6.6.0...

Terraform has been successfully initialized!
```

Run `terraform plan` to preview the resources that will be created. Provide your GitHub username when prompted for `github_owner`:

```bash
terraform plan -var="github_owner=YOUR_GITHUB_USERNAME"
```

Review the plan output. You should see the module repository (with its branch protection) and the standalone repository planned for creation.

Apply the configuration to create the resources:

```bash
terraform apply -var="github_owner=YOUR_GITHUB_USERNAME"
```

Type `yes` when prompted to confirm. Once complete, review the outputs to confirm your repositories were successfully created.

> 💡 **Tip:** To avoid typing `-var="github_owner=..."` on every command, export it once with `export TF_VAR_github_owner="YOUR_GITHUB_USERNAME"`. The remaining examples assume you have done this.

---

### Task 4: Inspect the Lock File

After `terraform init`, Terraform generates a `.terraform.lock.hcl` file to record the exact provider versions that were selected. This file should always be committed to version control.

Open the lock file and examine its contents:

```bash
cat .terraform.lock.hcl
```

You will see an entry for the GitHub provider that looks similar to this:

```hcl
provider "registry.terraform.io/integrations/github" {
  version     = "6.6.0"
  constraints = "~> 6.6.0"
  hashes = [
    "h1:...",
    ...
  ]
}
```

Notice that the lock file records:

- The **exact version** that was installed (`6.6.0`)
- The **constraint** from your configuration (`~> 6.6.0`)
- **Cryptographic hashes** to ensure integrity on future downloads

> 💡 The lock file ensures that every teammate running `terraform init` on this configuration will get the exact same provider version — even if newer patch releases have been published since you first ran `init`.

Note that the **module version** is recorded differently — it appears in the `.terraform/modules/modules.json` file. You can inspect it with:

```bash
cat .terraform/modules/modules.json
```

You should see the module source and version (`1.2.0`) recorded there for the `repo` module.

---

### Task 5: Upgrade the Provider Version

Your organization has decided to upgrade to the latest GitHub provider `6.13` release to take advantage of new resource support and bug fixes.

Open `providers.tf` and update the GitHub provider version constraint from `~> 6.6.0` to `~> 6.13.0`:

```hcl
terraform {
  required_version = ">= 1.12.2"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13.0"
    }
  }
}
```

If you run `terraform plan` at this point, Terraform will return an error because the lock file still references `6.6.0`, which no longer satisfies the new constraint. Try it to see the error:

```bash
terraform plan
```

You should see an error like:

```
Error: Inconsistent dependency lock file

The following dependency selections recorded in the lock file are inconsistent
with the current configuration:
  - provider registry.terraform.io/integrations/github: locked version
    selection 6.6.0 doesn't match the updated version constraints "~> 6.13.0"

To update the locked dependency selections to match a changed configuration,
run:
  terraform init -upgrade
```

This is Terraform's lock file protection in action. To update the lock file, you must explicitly pass the `-upgrade` flag to `terraform init`:

```bash
terraform init -upgrade
```

Terraform will now resolve and install a version that satisfies `~> 6.13.0`. Confirm that the lock file has been updated:

```bash
cat .terraform.lock.hcl
```

You should now see a newer version recorded (e.g., `6.13.0`) along with updated hashes.

---

### Task 6: Upgrade the Module Version

Next, you'll upgrade the community repository module from `1.2.0` to `1.2.5`. Module upgrades may include new input variables, additional sub-resources, or updated defaults — always review the module's release notes before upgrading in production.

Open `main.tf` and update the `version` argument in the `module "repo"` block:

```hcl
module "repo" {
  source  = "appvia/repository/github"
  version = "1.2.5"

  repository  = var.repository_name
  description = "Repository managed by the community module for the upgrade lab"
  visibility  = "public"
}
```

Run `terraform init -upgrade` again to download the updated module version:

```bash
terraform init -upgrade
```

You should see output confirming the new module version is being downloaded:

```
Downloading registry.terraform.io/appvia/repository/github 1.2.5 for repo...
```

Verify the module version has been updated in the modules manifest:

```bash
cat .terraform/modules/modules.json
```

---

### Task 7: Plan and Apply the Upgraded Configuration

Now that both the provider and module have been upgraded, run a plan to see if any infrastructure changes are required:

```bash
terraform plan
```

In many cases, a minor module or provider upgrade will result in **no infrastructure changes** — particularly when only new features or internal fixes were introduced. However, some upgrades introduce behavioral changes or new defaults that may result in planned modifications.

Review the plan output carefully before proceeding. If the plan shows only changes you expect (or no changes at all), apply the configuration:

```bash
terraform apply
```

Type `yes` when prompted. Confirm the outputs are still correct after the upgrade:

```bash
terraform output
```

Congrats, you've successfully upgraded both a Terraform provider and a community module while maintaining control over your infrastructure changes!

---

### Task 8: Clean Up Resources

Destroy all resources created during this lab to avoid leaving repositories behind in your account:

```bash
terraform destroy
```

Type `yes` when prompted. Verify in GitHub that both the module-managed repository and the standalone repository have been removed.

> 💡 If `terraform destroy` fails to delete a repository, confirm your token includes the `delete_repo` scope (classic token) or **Administration: Read and write** (fine-grained token), then run the command again.

---

## Summary

In this lab, you:

- Pinned a Terraform provider and community module to specific older versions
- Deployed free GitHub infrastructure using those pinned versions
- Inspected the `.terraform.lock.hcl` file to understand how versions are recorded and protected
- Upgraded the provider version constraint and used `terraform init -upgrade` to update the lock file
- Upgraded the module version by changing the `version` argument in the module block
- Applied the upgraded configuration and verified no unintended infrastructure changes occurred

---

> 🔍 **Observe:** Run `git diff .terraform.lock.hcl` after each upgrade to see exactly what changed in the lock file. Pay close attention to how the hashes change even for the same provider — this reflects the new binary being downloaded and verified.

> 🧪 **Challenge:** Try pinning the GitHub provider to an **exact** version (e.g., `version = "6.6.0"`) instead of using the `~>` pessimistic constraint operator. Then attempt `terraform init -upgrade` and observe how Terraform responds. Can you still upgrade to a newer version? Why or why not?

> 🧪 **Challenge:** Visit the [appvia/repository/github module documentation](https://registry.terraform.io/modules/appvia/repository/github/latest) and identify one feature or fix introduced between version `1.2.0` and `1.2.5`. How would you validate whether that change affects your configuration?
