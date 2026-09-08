# LAB-18-Azure: Refactoring State with the `moved` and `removed` Blocks

## Overview

In this lab, you will refactor your Terraform configuration **without destroying and recreating live infrastructure**. You'll build a small set of Azure networking resources, then see firsthand what happens when you rename a resource *without* a `moved` block. You'll fix the rename properly with a `moved` block, practice moving a resource into and back out of a child module, and then use `removed` blocks in both of their modes: first to destroy a resource you no longer need, and then to hand ownership of the remaining resources off so they stay in place while Terraform stops managing them.

The resources you orphan at the end of this lab are intentionally left in place so they can be imported back under Terraform management in a future lab. Delete them yourself when you're done (see [Clean Up](#clean-up)).

[![Lab 18](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

## Prerequisites

- Terraform installed (v1.12.2+)
- Azure account with an active subscription
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
3. Change into this lab's directory: `cd labs/lab_18_refactor_state_with_moved_and_removed_blocks/AZURE`
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
  description = "Azure region to deploy resources"
  type        = string
  default     = "eastus"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "lab"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "dev"
}

variable "lab_name" {
  description = "Lab identifier for tagging"
  type        = string
  default     = "lab18"
}

variable "vnet_cidr" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Address prefix for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}
```

### main.tf

```hcl
# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.azure_location

  tags = {
    Name        = "${var.prefix}-rg"
    Environment = var.environment
    Lab         = var.lab_name
  }
}

# Virtual Network
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

# Subnet
resource "azurerm_subnet" "app" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

# Route Table
resource "azurerm_route_table" "main" {
  name                = "${var.prefix}-rt"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = {
    Name        = "${var.prefix}-rt"
    Environment = var.environment
    Lab         = var.lab_name
  }
}

# Network Security Group
resource "azurerm_network_security_group" "web" {
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

## Lab Steps

### 1. Review and Deploy the Starting Configuration

Initialize the working directory, review the plan, then apply to create the five resources:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

> Yes, the Azure provider is slooow. Be patient :)

Terraform creates the resource group, virtual network, subnet, route table, and network security group.

### 2. Confirm the Resources Are Tracked in State

List the resources Terraform is managing:

```bash
terraform state list
```

You should see the following five addresses:

```
azurerm_network_security_group.web
azurerm_resource_group.main
azurerm_route_table.main
azurerm_subnet.app
azurerm_virtual_network.main
```

### 3. See What a Rename Does WITHOUT a `moved` Block

Suppose you want to rename the network security group resource from `web` to `app` to better reflect its purpose. Before reaching for a `moved` block, see how Terraform interprets a plain rename.

In `main.tf`, change the network security group resource label from `web` to `app`. Leave the `name` argument set to `"${var.prefix}-nsg"`:

```hcl
resource "azurerm_network_security_group" "app" {
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

Run a plan, but **DO NOT apply**:

```bash
terraform plan
```

Look closely at the output. Terraform has no idea these are the same resource. It sees `azurerm_network_security_group.web` vanish from the configuration and a brand-new `azurerm_network_security_group.app` appear, so it plans to destroy one and create the other:

```
Plan: 1 to add, 0 to change, 1 to destroy.
```

On a production system this means downtime at best. In this specific case the apply could even fail partway through, because a network security group name must be unique within a resource group, and the new group uses the same name as the group Terraform is destroying.

> Do not apply this plan. In the next step you'll tell Terraform what you actually meant.

### 4. Rename the Resource Properly with a `moved` Block

A `moved` block tells Terraform that the resource at a new address is the *same object* as the one at the old address, so it updates the state entry instead of destroying and recreating the resource.

Leave the renamed resource block in place and add the following `moved` block to `main.tf`:

```hcl
moved {
  from = azurerm_network_security_group.web
  to   = azurerm_network_security_group.app
}
```

Run a plan and confirm Terraform now reports a move with zero resources to add, change, or destroy:

```bash
terraform plan
```

You should see a line similar to:

```
azurerm_network_security_group.web has moved to azurerm_network_security_group.app
```

Apply the change, then confirm the resource now appears under its new address:

```bash
terraform apply -auto-approve
terraform state list
```

Once the move is applied, **delete the `moved` block** from `main.tf`. That's safe here because you're the only user of this configuration and you've already applied the move. In a shared module, you'd keep the `moved` block in place so other users get the same upgrade path.

### 5. Move the Subnet Into a Child Module

Renames aren't the only refactor a `moved` block can handle — it can also relocate a resource into a module. Suppose your team decides all networking resources should live in a reusable module.

Create the module directory:

```bash
mkdir -p modules/network
```

Create a new file at `modules/network/main.tf` with the following content:

```hcl
variable "resource_group_name" {
  description = "Name of the resource group where the subnet will be created"
  type        = string
}

variable "virtual_network_name" {
  description = "Name of the virtual network where the subnet will be created"
  type        = string
}

variable "subnet_cidr" {
  description = "Address prefix for the subnet"
  type        = string
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

resource "azurerm_subnet" "app" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.subnet_cidr]
}
```

In `main.tf`, delete the `azurerm_subnet.app` resource block and replace it with a module block and a `moved` block:

```hcl
module "network" {
  source = "./modules/network"

  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  subnet_cidr          = var.subnet_cidr
  prefix               = var.prefix
}

moved {
  from = azurerm_subnet.app
  to   = module.network.azurerm_subnet.app
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
azurerm_subnet.app has moved to module.network.azurerm_subnet.app
```

Apply the change, then confirm the subnet now lives at a module address:

```bash
terraform apply -auto-approve
terraform state list
```

The subnet appears as `module.network.azurerm_subnet.app`. The real subnet in Azure was never touched.

### 6. Move the Subnet Back to the Root Module

Moves work in both directions. A future import lab expects these resources in a flat configuration, so move the subnet back to the root module before the handoff.

First, delete the `moved` block you added in Step 5 — it has been applied and has served its purpose.

In `main.tf`, delete the `module "network"` block and restore the original subnet resource block:

```hcl
resource "azurerm_subnet" "app" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}
```

Add a `moved` block pointing in the opposite direction:

```hcl
moved {
  from = module.network.azurerm_subnet.app
  to   = azurerm_subnet.app
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

### 7. Destroy the Route Table with a `removed` Block

A `removed` block tells Terraform to stop managing a resource. It has two modes, and this step demonstrates the default one: remove the resource from state **AND** destroy the real infrastructure.

Your configuration no longer needs the route table, so retire it the configuration-driven way. In `main.tf`, delete the `azurerm_route_table.main` resource block and add the following `removed` block in its place:

```hcl
removed {
  from = azurerm_route_table.main

  lifecycle {
    destroy = true
  }
}
```

The `destroy` argument is set to `true` here for clarity, but `true` is the default. Run a plan and note the difference from every plan so far in this lab — this one destroys real infrastructure:

```bash
terraform plan
```

You should see:

```
Plan: 0 to add, 0 to change, 1 to destroy.
```

Apply the change, then confirm the route table is gone from state:

```bash
terraform apply -auto-approve
terraform state list
```

You should see only four addresses remaining. If you check the Azure Portal, the route table has been deleted. Keep this result in mind — in Step 9 you'll use the same block type with one argument flipped to get the opposite behavior.

Once the apply completes, **delete the `removed` block** from `main.tf`.

### 8. Add Output Blocks to Retrieve the Resource IDs

Before you orphan the remaining resources, capture their IDs. You'll need them to import these resources back in a future lab.

Create a new `outputs.tf` file with the following content:

```hcl
output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = azurerm_subnet.app.id
}

output "network_security_group_id" {
  description = "ID of the network security group"
  value       = azurerm_network_security_group.app.id
}
```

Run a plan and apply to render the outputs:

```bash
terraform plan
terraform apply -auto-approve
```

In the terminal you'll see the four output values (full Azure resource IDs). **Write these IDs down somewhere safe** — a future import lab uses them as the import identifiers.

### 9. Orphan the Remaining Resources with `removed` Blocks

In Step 7, a `removed` block destroyed the route table. Setting the `lifecycle` `destroy` argument to `false` changes the behavior entirely: Terraform forgets the resource but leaves it untouched in Azure.

Delete all four resource blocks from `main.tf`. Also **delete the `outputs.tf` file**, because its outputs reference the resources you're about to remove and would cause an error once those resources leave the configuration. You already recorded the IDs in Step 8.

Add the following four `removed` blocks to `main.tf` in place of the deleted resource blocks:

```hcl
removed {
  from = azurerm_resource_group.main

  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_virtual_network.main

  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_subnet.app

  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_network_security_group.app

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

Use the Azure Portal to confirm the resources still exist: open the resource group and confirm the virtual network, subnet, and network security group are all still present. They exist, but they're no longer under Terraform management — ready to be imported in a future lab.

## Clean Up

> `terraform destroy` will **not** remove these resources, because your state file is now empty. The route table was already destroyed by Terraform in Step 7, so only the resource group and its contents remain.

Delete the remaining resources in the Azure Portal: open **Resource groups**, select the lab resource group, and choose **Delete resource group**. Deleting the resource group removes the virtual network, subnet, and network security group in one action.

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

1. Move *all* of the networking resources into the child module in a single refactor (not just the subnet), using one `moved` block per resource.
2. After orphaning the resources, run `terraform import` to bring the resource group back under management using the ID you captured in Step 8.
3. Add a second `moved` block that renames a resource *and* moves it into a module in the same apply, and confirm Terraform still reports zero changes.
