# LAB-20-Azure: Migrating State to a Remote Azure Backend with State Locking

## Overview

In this lab, you will migrate Terraform state from the local backend to a remote Azure Storage backend with state locking. You will inspect the local state file, provision a storage account for state, migrate state with `terraform init -migrate-state`, strand and repair a state lock with `terraform force-unlock`, and migrate state back to local before cleaning up.

[![Lab 20](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

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
3. Change into this lab's directory: `cd labs/lab_20_migrate_state_to_a_new_backend/AZURE`
4. Follow the instructions below to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time

30 minutes

## Initial Configuration Files

This lab ships with three starter files in the working directory — `providers.tf`, `variables.tf`, and `main.tf` — plus an `azure_backend` subdirectory. The `azure_backend` directory is a small bootstrap configuration that creates the state storage account and keeps its own local state, since the storage account has to exist before the backend that uses it can be initialized.

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
  }
}

# Subnet
resource "azurerm_subnet" "app" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

# Network Security Group
resource "azurerm_network_security_group" "app" {
  name                = "${var.prefix}-app-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = {
    Name        = "${var.prefix}-app-nsg"
    Environment = var.environment
  }
}
```

### azure_backend/main.tf

```hcl
terraform {
  required_version = ">= 1.12.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Used to build a globally unique storage account name
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Resource group for the state storage account
resource "azurerm_resource_group" "state" {
  name     = "lab-tfstate-rg"
  location = "eastus"

  tags = {
    Name    = "lab-tfstate-rg"
    Purpose = "terraform-remote-state"
  }
}

# Storage account that will store the Terraform state file
resource "azurerm_storage_account" "state" {
  name                     = "labtfstate${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Keep old versions of the state file so it can be recovered
  blob_properties {
    versioning_enabled = true
  }

  tags = {
    Name    = "lab-tfstate"
    Purpose = "terraform-remote-state"
  }
}

# Container that will hold the state blob
resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

output "storage_account_name" {
  description = "Name of the storage account that stores Terraform state"
  value       = azurerm_storage_account.state.name
}
```

## Lab Steps

### 1. Deploy the Starting Configuration on the Local Backend

There is no `backend` block in `providers.tf`, so Terraform uses the local backend and stores state in a `terraform.tfstate` file in the working directory.

Initialize and deploy the four networking resources:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

### 2. Inspect the Local State File

Confirm the state file exists on local disk:

```bash
ls -l terraform.tfstate
```

List the resources Terraform recorded in it:

```bash
terraform state list
```

```
azurerm_network_security_group.app
azurerm_resource_group.main
azurerm_subnet.app
azurerm_virtual_network.main
```

### 3. Provision the Azure State Storage Account

Move into the bootstrap directory:

```bash
cd azure_backend
```

Review `main.tf`. The storage account name ends in a random suffix because storage account names are globally unique across all of Azure, and `versioning_enabled = true` keeps every version of the state blob. The resource group and container use fixed names (`lab-tfstate-rg` and `tfstate`) that you will reference in the backend block.

Deploy the storage account:

```bash
terraform init
terraform apply -auto-approve
```

```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

storage_account_name = "labtfstate4k2j9x1q"
```

Record the `storage_account_name` value, then return to the working directory:

```bash
cd ..
```

### 4. Add the backend Block

In `providers.tf`, add a `backend "azurerm"` block inside the `terraform` block, replacing `<YOUR_STORAGE_ACCOUNT_NAME>` with the storage account name you recorded in Step 3:

```hcl
terraform {
  required_version = ">= 1.12.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "lab-tfstate-rg"
    storage_account_name = "<YOUR_STORAGE_ACCOUNT_NAME>"
    container_name       = "tfstate"
    key                  = "networking.terraform.tfstate"
  }
}
```

Backend blocks cannot use variables, so every value must be a literal string.

Run a plan **without** re-initializing:

```bash
terraform plan
```

```
Error: Backend initialization required, please run "terraform init"

Reason: Initial configuration of the requested backend "azurerm"
```

Any change to the backend configuration requires running `terraform init` again.

### 5. Migrate State to Azure Storage

Re-initialize with the `-migrate-state` flag:

```bash
terraform init -migrate-state
```

```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local"
  backend to the newly configured "azurerm" backend. No existing
  state was found in the newly configured "azurerm" backend. Do you
  want to copy this state to the new "azurerm" backend? Enter "yes"
  to copy and "no" to start with an empty state.

  Enter a value:
```

Answer `yes` to copy your existing state into Azure Storage:

```
Successfully configured the backend "azurerm"! Terraform will
automatically use this backend unless the backend configuration
changes.
```

> If you answer `no` by mistake, your state is still on disk; upload it with `terraform state push terraform.tfstate`.

### 6. Verify the Migration

Confirm Terraform still tracks all four resources:

```bash
terraform state list
```

```
azurerm_network_security_group.app
azurerm_resource_group.main
azurerm_subnet.app
azurerm_virtual_network.main
```

Pull the state directly from the backend to prove it is served from Azure Storage:

```bash
terraform state pull | head -n 7
```

```
{
  "version": 4,
  "terraform_version": "1.12.2",
  "serial": 1,
  "lineage": "3f8a2c71-example-lineage-uuid",
  "outputs": {},
  "resources": [
```

You can also open the Azure portal, go to your storage account, open the `tfstate` container, and find the `networking.terraform.tfstate` blob.

Run a plan against the remote state:

```bash
terraform plan
```

```
No changes. Your infrastructure matches the configuration.
```

The local `terraform.tfstate` is now a stale copy. Delete it:

```bash
rm terraform.tfstate
```

### 7. Break and Repair a State Lock

The `azurerm` backend locks the state blob automatically with a blob lease; no extra argument is required.

In `main.tf`, add a `Purpose` tag to the network security group so there is a change to apply later:

```hcl
  tags = {
    Name        = "${var.prefix}-app-nsg"
    Environment = var.environment
    Purpose     = "lab-locking-demo"
  }
```

Start a plan in the background, give it two seconds to acquire the lock, then kill the process before it can release the lock:

```bash
terraform plan > /dev/null 2>&1 &
sleep 2 && kill -9 $!
```

The lease is now stranded on the state blob. Run a normal plan:

```bash
terraform plan
```

```
Error: Error acquiring the state lock

Error message: state blob is already locked

Lock Info:
  ID:        b7a4e6c2-7c2d-4f7a-9d31-example0001
  Path:      tfstate/networking.terraform.tfstate
  Operation: OperationTypePlan
  Who:       user@codespace
  Version:   1.12.2
  Created:   2026-07-09 14:25:03 UTC
```

> If you see a normal plan instead of this error, the plan finished before the kill landed; run the two background commands again.

Record the `ID` value from the `Lock Info` block. To see the lock itself, open the `networking.terraform.tfstate` blob in the Azure portal: its lease state shows **Leased**.

Remove the stranded lock with `force-unlock`, substituting your lock ID:

```bash
terraform force-unlock b7a4e6c2-7c2d-4f7a-9d31-example0001
```

```
Do you really want to force-unlock?
  Terraform will remove the lock on the remote state.
  This will allow local Terraform commands to modify this state,
  even though it may still be in use. Only 'yes' will be accepted
  to confirm.

  Enter a value: yes

Terraform state has been successfully unlocked!
```

Force-unlock is safe here because the process that held the lock is dead. If the lock holder is alive and just slow, use `-lock-timeout` instead (for example, `terraform plan -lock-timeout=60s`).

Confirm the lock is gone and apply the pending tag change:

```bash
terraform plan
```

```
Plan: 0 to add, 1 to change, 0 to destroy.
```

```bash
terraform apply -auto-approve
```

```
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

### 8. View State File Versions

Open the Azure portal, go to your storage account, open the `tfstate` container, click the `networking.terraform.tfstate` blob, and open the **Versions** tab. The blob has at least two versions: one from the migration in Step 5 and one from the apply in Step 7. Any previous version can be restored if the current state is ever corrupted.

### 9. Migrate State Back to Local

The same recipe works in any direction: change the backend configuration, then run `terraform init -migrate-state`. In `providers.tf`, delete (or comment out) the entire `backend "azurerm"` block, then run:

```bash
terraform init -migrate-state
```

```
Initializing the backend...
Terraform has detected you're unconfiguring your previously set
"azurerm" backend.

Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous
  "azurerm" backend to the newly configured "local" backend. No
  existing state was found in the newly configured "local" backend.
  Do you want to copy this state to the new "local" backend? Enter
  "yes" to copy and "no" to start with an empty state.

  Enter a value:
```

Answer `yes`. If you answer `no` by mistake, re-add the backend block, run `terraform init -reconfigure`, and start this step over.

Verify the round trip:

```bash
terraform state list
ls -l terraform.tfstate
```

All four resources are still tracked, and `terraform.tfstate` is back on local disk.

## Clean Up

Destroy the networking resources:

```bash
terraform destroy -auto-approve
```

Destroy the state storage account (deleting the storage account removes the state blob and all of its versions):

```bash
cd azure_backend
terraform destroy -auto-approve
```

Remove the leftover local state files:

```bash
cd ..
rm -f terraform.tfstate terraform.tfstate.backup
rm -f azure_backend/terraform.tfstate azure_backend/terraform.tfstate.backup
```

## Key Concepts

- Backend configuration is evaluated before anything else: values must be literals, and any change requires re-running `terraform init`.
- `terraform init -migrate-state` copies state between any two backends, in either direction. The `-reconfigure` flag switches backends **without** copying state.
- The `azurerm` backend locks the state blob automatically with a blob lease. The "state blob is already locked" error in Step 7 was the backend failing to acquire the lease. The lease is released when the operation ends, so only a killed process leaves a stale lock.
- The state blob lives at `container_name` plus `key` inside the storage account; `resource_group_name` and `storage_account_name` tell Terraform where to find it, and your Azure CLI login supplies the credentials.
- `terraform force-unlock` removes a stale lock and requires the lock ID; `-lock-timeout` waits for a live one.
- Azure Storage encrypts all blobs at rest by default; blob versioning makes every state write recoverable.

## Additional Challenge

1. Change the `key` argument to `networking/v2.terraform.tfstate` and migrate the state to its new path with `terraform init -migrate-state`. Confirm in the portal that the blob moved — and notice the old blob is left behind as a stale copy.
2. Re-create the stranded lock from Step 7, but this time run `terraform plan -lock-timeout=120s` and watch it retry instead of failing immediately, then force-unlock from where you left off.
3. Run `terraform force-unlock -help` and read the description. When would you need it, and why does it demand the lock ID as an argument?
