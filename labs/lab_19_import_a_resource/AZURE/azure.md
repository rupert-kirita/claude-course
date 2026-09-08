# LAB-19-Azure: Importing an Existing Resource

## Overview

In this lab, you will bring existing, unmanaged Azure resources under Terraform management using both the `terraform import` CLI command and the `import` block. You'll start with live infrastructure and an **empty state file**, import each resource, and prove the configuration matches with a clean plan.

This lab picks up exactly where [Lab 18](../../lab_18_refactor_state_with_moved_and_removed_blocks/AZURE/azure.md) left off: the resource group, virtual network, subnet, and network security group you orphaned with `removed` blocks still exist in Azure, but Terraform no longer knows about them. By the end of this lab they are back under Terraform management — and a final `terraform destroy` cleans up everything Lab 18 left behind.

[![Lab 19](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

## Prerequisites

- Terraform installed (v1.12.2+)
- Azure account with an active subscription
- The orphaned resources from Lab 18 (`lab-rg`, `lab-vnet`, `lab-subnet`, `lab-nsg`) still in place — see the note in Step 1 if you skipped Lab 18
- Basic understanding of Terraform and Azure concepts

Note: Azure credentials are required for this lab. Authenticate and select your subscription before you begin:

```bash
az login
az account set --subscription "<your-subscription-name-or-id>"
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
```

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).
2. Once the Codespace is running, open the integrated terminal.
3. Change into this lab's directory: `cd labs/lab_19_import_a_resource/AZURE`
4. Follow the instructions below to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time

30 minutes

## Initial Configuration Files

This lab ships with three starter files in the working directory: `providers.tf`, `variables.tf`, and `main.tf`. Unlike previous labs, `main.tf` starts out empty — the resources already exist in Azure, and your job is to write the configuration that matches them.

### providers.tf

```hcl
terraform {
  required_version = ">= 1.12.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

### variables.tf

```hcl
variable "azure_location" {
  description = "Azure region where the Lab 18 resources live"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "lab"
}

variable "environment" {
  description = "Environment name for tagging (must match the existing resources)"
  type        = string
  default     = "dev"
}

variable "lab_name" {
  description = "Lab identifier for tagging (the existing resources were tagged by Lab 18)"
  type        = string
  default     = "lab18"
}

variable "vnet_cidr" {
  description = "Address space of the existing virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Address prefix of the existing subnet"
  type        = string
  default     = "10.0.1.0/24"
}
```

> `lab_name` defaults to `lab18` on purpose — the `Lab` tag on the real resources was stamped by Lab 18, and your configuration must describe the resources as they exist.

### main.tf

```hcl
# This file starts intentionally empty.
#
# The resource group, virtual network, subnet, and network security
# group created in Lab 18 still exist in Azure, but they are no longer
# tracked in Terraform state. During this lab you will add resource and
# import blocks here to bring each one back under Terraform management.
```

## Lab Steps

### 1. Confirm the Orphaned Resources Still Exist

Lab 18 ended with `removed` blocks that took the resource group, virtual network, subnet, and network security group out of Terraform state while leaving them running in Azure.

Azure import IDs are full ARM resource IDs — long paths that start with `/subscriptions/...`. If you recorded the four IDs in Lab 18 Step 8, you can use those. Otherwise, retrieve them with the Azure CLI:

```bash
az group show --name lab-rg --query id --output tsv

az network vnet show --resource-group lab-rg --name lab-vnet \
  --query id --output tsv

az network vnet subnet show --resource-group lab-rg --vnet-name lab-vnet \
  --name lab-subnet --query id --output tsv

az network nsg show --resource-group lab-rg --name lab-nsg \
  --query id --output tsv
```

You can also find each ID in the Azure Portal by opening the resource and choosing **Properties** (or **JSON View**) to see its **Resource ID**.

> **Skipped Lab 18?** Create the resources manually in the Azure Portal first: a resource group named `lab-rg` in `eastus`, a virtual network named `lab-vnet` with address space `10.0.0.0/16`, a subnet named `lab-subnet` with address prefix `10.0.1.0/24`, and a network security group named `lab-nsg`. Tag everything except the subnet with `Name` = the resource's own name, `Environment = dev`, and `Lab = lab18` (Azure subnets do not support tags). Then continue from here.

### 2. Initialize and Confirm the State Is Empty

Initialize the working directory, then list the resources Terraform is managing:

```bash
terraform init
terraform state list
```

The `terraform state list` command returns nothing. Real infrastructure exists, but the state file knows about none of it.

### 3. Write a Resource Block for the Resource Group

Start with the `terraform import` CLI command. As a reminder, it does not write configuration for you, and it refuses to run until a resource block for the target address exists — so the resource block comes first.

Add the following resource block to `main.tf`, describing the resource group exactly as it exists in Azure:

```hcl
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.azure_location

  tags = {
    Name        = "${var.prefix}-rg"
    Environment = var.environment
    Lab         = var.lab_name
  }
}
```

> The address does not need to match the one Lab 18 used. What must match is the real resource's attributes, like its name, location, and all three tags.

### 4. Import the Resource Group with the `terraform import` Command

Run the import command. Because you exported `ARM_SUBSCRIPTION_ID` in the prerequisites, you can use it to build the ARM ID inline:

```bash
terraform import azurerm_resource_group.main \
  /subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/lab-rg
```

You should see output similar to:

```
azurerm_resource_group.main: Importing from ID "/subscriptions/.../resourceGroups/lab-rg"...
azurerm_resource_group.main: Import prepared!
  Prepared azurerm_resource_group for import
azurerm_resource_group.main: Refreshing state... [id=/subscriptions/.../resourceGroups/lab-rg]

Import successful!

The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.
```

Confirm the resource group is back in state:

```bash
terraform state list
```

You should see exactly one address:

```
azurerm_resource_group.main
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

> If the plan shows changes, your configuration does not match the real resource. Fix the **configuration**, not the infrastructure, and plan again until it is clean.

### 6. Import the Virtual Network and Subnet with `import` Blocks

Next, use the `import` block. Instead of running a command per resource, you declare the import in configuration and let a single apply handle several imports at once.

Add the following to `main.tf`, substituting your virtual network and subnet ARM IDs from Step 1:

```hcl
import {
  to = azurerm_virtual_network.main
  id = "/subscriptions/<your-subscription-id>/resourceGroups/lab-rg/providers/Microsoft.Network/virtualNetworks/lab-vnet"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.vnet_cidr]

  tags = {
    Name        = "${var.prefix}-vnet"
    Environment = var.environment
    Lab         = var.lab_name
  }
}

import {
  to = azurerm_subnet.app
  id = "/subscriptions/<your-subscription-id>/resourceGroups/lab-rg/providers/Microsoft.Network/virtualNetworks/lab-vnet/subnets/lab-subnet"
}

resource "azurerm_subnet" "app" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}
```

> Notice the subnet's ARM ID nests under the virtual network's ID, and the subnet block has no `tags` because Azure subnets do not support them.

Run a plan:

```bash
terraform plan
```

The plan now includes both import operations:

```
Plan: 2 to import, 0 to add, 0 to change, 0 to destroy.
```

Nothing has happened yet, because import blocks perform the import at **apply** time. Don't apply yet — first, add the network security group so a single apply imports all three resources.

### 7. Generate the Network Security Group Configuration Automatically

For the virtual network and subnet, you hand-wrote the resource blocks. For the network security group, let Terraform write it for you. Add **only** an import block to `main.tf` — no resource block this time — substituting your NSG's ARM ID from Step 1:

```hcl
import {
  to = azurerm_network_security_group.main
  id = "/subscriptions/<your-subscription-id>/resourceGroups/lab-rg/providers/Microsoft.Network/networkSecurityGroups/lab-nsg"
}
```

Now generate configuration for any import target that has no matching resource block:

```bash
terraform plan -generate-config-out=generated.tf
```

Open `generated.tf` and review it. Every value is a hardcoded literal (the `resource_group_name` and `location` are raw strings instead of references to `azurerm_resource_group.main`), and every settable attribute is listed, including an empty `security_rule` set. Move the resource block into `main.tf` and clean it up so it looks like this:

```hcl
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = {
    Name        = "${var.prefix}-nsg"
    Environment = var.environment
    Lab         = var.lab_name
  }
}
```

Delete the now-empty `generated.tf` file, then run a plan to confirm all three pending imports are recognized:

```bash
terraform plan
```

```
Plan: 3 to import, 0 to add, 0 to change, 0 to destroy.
```

### 8. Apply to Complete the Imports

Run the apply:

```bash
terraform apply -auto-approve
```

Terraform imports all three resources in one operation:

```
Apply complete! Resources: 3 imported, 0 added, 0 changed, 0 destroyed.
```

### 9. Verify Everything Is Under Management

List the state one more time:

```bash
terraform state list
```

You should see all four resources:

```
azurerm_network_security_group.main
azurerm_resource_group.main
azurerm_subnet.app
azurerm_virtual_network.main
```

Run a final plan and confirm it comes back clean:

```bash
terraform plan
```

```
No changes. Your infrastructure matches the configuration.
```

Finally, **delete the three `import` blocks** from `main.tf`. Like `moved` and `removed` blocks, they describe a one-time operation and can be removed once applied.

## Clean Up

Now that Terraform manages the resources again, `terraform destroy` works.

Destroy the infrastructure:

```bash
terraform destroy -auto-approve
```

Terraform removes the subnet, network security group, and virtual network before the resource group that contains them:

```
Destroy complete! Resources: 4 destroyed.
```

This removes the resources Lab 18 intentionally left behind.

## Key Concepts

### Importing Changes State, Never Infrastructure

- Both methods bind a resource address to a real object — the object itself is untouched.
- Terraform does not reconcile your configuration on import; it simply starts comparing the two. A clean plan is the proof the import worked.

### Azure Imports Use Full ARM Resource IDs

- Every Azure import ID is the complete ARM path, built from names you already know — so you can often construct them by hand instead of looking them up. Child resources like subnets nest under their parent's ID.

### Two Methods, One Goal

| | `terraform import` (CLI) | `import` block (config-driven) |
| --- | --- | --- |
| Style | Imperative, one command per resource | Declarative, lives in your configuration |
| Configuration | You must hand-write the resource block first | Optional generation via `-generate-config-out` |
| Scale | One resource at a time | Many resources in a single apply |
| Reviewability | Runs from your terminal, leaves no trace in the repo | Visible in version control and code review |

### Generated Configuration Needs Cleanup

- `-generate-config-out` hardcodes every value as a literal and includes every settable attribute — treat it as a draft: replace literals with references and variables, prune, and review before applying.
- Like `moved` and `removed` blocks, `import` blocks describe a one-time operation and can be deleted once applied.

## Additional Challenge

1. Recreate the `outputs.tf` file from Lab 18 Step 8 (resource group, virtual network, subnet, and NSG IDs) and confirm the output values match the ARM IDs you imported — proof that these are the very same resources.
2. Introduce deliberate drift before the final destroy: change the virtual network's `Name` tag in your configuration to a different value, run `terraform plan`, and observe how Terraform proposes an in-place update. Revert the change and confirm the plan is clean again.
3. Inspect an imported resource in detail with `terraform state show azurerm_virtual_network.main` and compare each attribute against your resource block. How many attributes does the state track that your configuration never mentions?
