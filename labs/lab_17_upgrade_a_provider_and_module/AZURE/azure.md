# LAB-17-AZURE: Upgrading a Terraform Provider and Module

This lab demonstrates how to safely upgrade a Terraform provider and a community module to newer versions. You'll learn how to interpret version constraints, inspect the `.terraform.lock.hcl` file, and use `terraform init -upgrade` to pull in updated dependencies — all using free Azure resources.

> 📖 **Preview Mode:** Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

> ☁️ **Note:** Azure credentials are required for this lab. Create a Codespace from this repo (click the button below). Once the Codespace is running, open the integrated terminal. Follow the instructions in each lab to complete the exercises.

## Lab Overview

In this lab, you will:

- Pin an Azure provider and community module to specific older versions
- Deploy infrastructure using those pinned versions
- Inspect the `.terraform.lock.hcl` file to understand how versions are recorded and protected
- Upgrade the Azure provider using `terraform init -upgrade`
- Upgrade the module version by changing the `version` argument
- Apply the upgraded configuration and verify no unintended infrastructure changes occurred

---

## Task 1: Create a New Working Directory and Initial Configuration

In this task, you'll create a fresh working directory and write a Terraform configuration that intentionally uses **older** pinned versions of both the Azure provider and the popular `Azure/network/azurerm` community module.

Create and navigate to a new working directory:

```bash
mkdir ~/lab_upgrading_providers && cd ~/lab_upgrading_providers
```

Create a `versions.tf` file to declare the required providers with an older version constraint:

```hcl
terraform {
  required_version = ">= 1.12.2"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}
```

Create a `main.tf` file with the Azure provider, a resource group, a storage account, and a community network module pinned to an older version:

```hcl
provider "azurerm" {
  features {}
}

# Resource Group - all resources will be created inside this group
resource "azurerm_resource_group" "example" {
  name     = "rg-terraform-upgrade-lab"
  location = "East US"

  tags = {
    Name        = "Terraform Upgrade Lab"
    Terraform   = "true"
    Environment = "lab"
  }
}

# Using a pinned older version of the Azure community network module
module "network" {
  source  = "Azure/network/azurerm"
  version = "5.3.0"

  resource_group_name = azurerm_resource_group.example.name
  vnet_name           = "vnet-upgrade-lab"
  address_space       = "10.0.0.0/16"

  subnet_prefixes = ["10.0.1.0/24", "10.0.2.0/24"]
  subnet_names    = ["subnet-app", "subnet-data"]

  tags = {
    Terraform   = "true"
    Environment = "lab"
  }

  depends_on = [azurerm_resource_group.example]
}

# Standalone Storage Account using only free-tier resources
resource "azurerm_storage_account" "example" {
  name                     = "stterraformupgradelab"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Name        = "Terraform Upgrade Lab Storage"
    Terraform   = "true"
    Environment = "lab"
  }
}
```

> ⚠️ **Important:** Azure storage account names must be globally unique and contain only lowercase letters and numbers with a length between 3 and 24 characters. Update the `name` argument in the `azurerm_storage_account` block to make it unique (e.g., append your initials).

Create an `outputs.tf` file so you can verify what was created:

```hcl
output "resource_group_name" {
  description = "Name of the Resource Group"
  value       = azurerm_resource_group.example.name
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = module.network.vnet_id
}

output "subnet_ids" {
  description = "IDs of the subnets"
  value       = module.network.vnet_subnets
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.example.name
}
```

---

## Task 2: Initialize and Deploy the Initial Infrastructure

Run `terraform init` to download the pinned provider and module versions:

```bash
terraform init
```

You should see output similar to the following, confirming which versions were installed:

```
Initializing the backend...
Initializing modules...
Downloading registry.terraform.io/Azure/network/azurerm 5.3.0 for network...

Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 3.100"...
- Installing hashicorp/azurerm v3.110.0...

Terraform has been successfully initialized!
```

Run `terraform plan` to preview the resources that will be created:

```bash
terraform plan
```

Review the plan output. You should see the resource group, virtual network, two subnets, and the storage account planned for creation.

Apply the configuration to create the resources:

```bash
terraform apply
```

Type `yes` when prompted to confirm. Once complete, review the outputs to confirm your resources were successfully created.

---

## Task 3: Inspect the Lock File

After `terraform init`, Terraform generates a `.terraform.lock.hcl` file to record the exact provider versions that were selected. This file should always be committed to version control.

Open the lock file and examine its contents:

```bash
cat .terraform.lock.hcl
```

You will see an entry for the Azure provider that looks similar to this:

```hcl
provider "registry.terraform.io/hashicorp/azurerm" {
  version     = "3.110.0"
  constraints = "~> 3.100"
  hashes = [
    "h1:...",
    ...
  ]
}
```

Notice that the lock file records:

- The **exact version** that was installed (e.g., `3.110.0`)
- The **constraint** from your configuration (`~> 3.100`)
- **Cryptographic hashes** to ensure integrity on future downloads

> 💡 The lock file ensures that every teammate running `terraform init` on this configuration will get the exact same provider version — even if newer patch releases have been published since you first ran `init`.

The **module version** is recorded separately in the `.terraform/modules/modules.json` file. You can inspect it with:

```bash
cat .terraform/modules/modules.json
```

You should see the module source and version (`5.3.0`) recorded there.

---

## Task 4: Upgrade the Provider Version

Your organization has decided to upgrade to the latest `3.x` Azure provider release to take advantage of new resource support and bug fixes.

Open `versions.tf` and update the Azure provider version constraint from `~> 3.100` to `~> 3.116`:

```hcl
terraform {
  required_version = ">= 1.12.2"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
  }
}
```

If you run `terraform plan` at this point, Terraform will return an error because the lock file still references `3.110.x`, which no longer satisfies the new constraint. Try it to see the error:

```bash
terraform plan
```

You should see an error like:

```
Error: Failed to query available provider packages

Could not retrieve the list of available versions for provider hashicorp/azurerm:
locked provider registry.terraform.io/hashicorp/azurerm 3.110.0 does not match
configured version constraint ~> 3.116; must use terraform init -upgrade to allow
selection of new versions
```

This is Terraform's lock file protection in action. To update the lock file, you must explicitly pass the `-upgrade` flag to `terraform init`:

```bash
terraform init -upgrade
```

Terraform will now resolve and install a version that satisfies `~> 3.116`. Confirm that the lock file has been updated:

```bash
cat .terraform.lock.hcl
```

You should now see a newer version recorded (e.g., `3.116.0` or later) along with updated hashes.

---

## Task 5: Upgrade the Module Version

Next, you'll upgrade the community Azure network module from `5.3.0` to `5.5.0`. Module upgrades may include new input variables, additional sub-resources, or updated defaults — always review the module's CHANGELOG before upgrading in production.

Open `main.tf` and update the `version` argument in the `module "network"` block:

```hcl
module "network" {
  source  = "Azure/network/azurerm"
  version = "5.5.0"

  resource_group_name = azurerm_resource_group.example.name
  vnet_name           = "vnet-upgrade-lab"
  address_space       = "10.0.0.0/16"

  subnet_prefixes = ["10.0.1.0/24", "10.0.2.0/24"]
  subnet_names    = ["subnet-app", "subnet-data"]

  tags = {
    Terraform   = "true"
    Environment = "lab"
  }

  depends_on = [azurerm_resource_group.example]
}
```

Run `terraform init -upgrade` again to download the updated module version:

```bash
terraform init -upgrade
```

You should see output confirming the new module version is being downloaded:

```
Downloading registry.terraform.io/Azure/network/azurerm 5.5.0 for network...
```

Verify the module version has been updated in the modules manifest:

```bash
cat .terraform/modules/modules.json
```

---

## Task 6: Plan and Apply the Upgraded Configuration

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

---

## Task 7: Clean Up Resources

Destroy all resources created during this lab to avoid any potential charges:

```bash
terraform destroy
```

Type `yes` when prompted. Verify in the Azure Portal that the resource group, virtual network, subnets, and storage account have all been removed.

---

## Summary

In this lab, you:

- Pinned a Terraform Azure provider and a community module to specific older versions
- Deployed free Azure infrastructure using those pinned versions
- Inspected the `.terraform.lock.hcl` file to understand how versions are recorded and protected
- Upgraded the provider version constraint and used `terraform init -upgrade` to update the lock file
- Upgraded the community module version by changing the `version` argument
- Applied the upgraded configuration and verified no unintended infrastructure changes occurred

---

> 🔍 **Observe:** Run `git diff .terraform.lock.hcl` after each upgrade to see exactly what changed in the lock file. Pay close attention to how the hashes change even for the same provider — this reflects the new binary being downloaded and verified.

> 🧪 **Challenge:** Try pinning the Azure provider to an **exact** version (e.g., `version = "3.110.0"`) instead of using the `~>` pessimistic constraint operator. Then attempt `terraform init -upgrade` and observe how Terraform responds. Can you still upgrade to a newer version? Why or why not?

> 🧪 **Challenge:** Visit the [Azure/network/azurerm module changelog](https://github.com/Azure/terraform-azurerm-network/blob/main/CHANGELOG.md) and identify one feature or fix introduced between version `5.3.0` and `5.5.0`. How would you validate whether that change affects your configuration?