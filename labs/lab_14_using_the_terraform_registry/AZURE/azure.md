# LAB-14-AZURE: Using Terraform Registry Modules

## Overview
In this lab, you will learn how to use modules from the Terraform Registry to deploy Azure infrastructure efficiently. You'll use multiple modules, pass outputs between them, and reuse the same module with different parameters. The lab uses free-tier-compatible Azure resources.

[![Lab 14](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed
- Azure subscription
- Azure CLI installed and authenticated

Note: You must be logged into Azure CLI (`az login`) before running this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo.  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each section to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time
15 minutes

## Initial Configuration Files

The lab directory contains the following initial files:

- `main.tf`
- `variables.tf`
- `providers.tf`

## Lab Steps

### 1. Configure Azure Credentials

First, ensure you're logged into Azure:

```bash
az login
```

Set the Azure Subscription ID using the environment variable:
```bash
export ARM_SUBSCRIPTION_ID=abcde-12345-abcde-67890-abcde
```

### 2. Set Up the Provider Configuration

Add the `random` provider to your `providers.tf` file:

```hcl
terraform {
  required_version = ">= 1.12.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {                        #  <--- add this block
      source  = "hashicorp/random"
      version = ">=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

### 3. Create Variables

Add the following variable definition to your `variables.tf` file:

```hcl
# Simple map of subnet configurations
variable "subnets" {
  description = "Map of subnet names to address prefixes"
  type        = map(string)
  default = {
    "web"   = "10.0.1.0/24"
    "app"   = "10.0.2.0/24"
    "data"  = "10.0.3.0/24"
    "mgmt"  = "10.0.4.0/24"
  }
}
```

### 4. Create an Azure Resource Group and then a Virtual Network using a Module from the Terraform Registry:

Add the following blocks to your `main.tf` file:

```hcl
# Resource Group
resource "azurerm_resource_group" "example" {
  name     = "rg-${var.environment}-modules"
  location = var.location
  
  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# Use the Virtual Network module from Terraform Registry
module "vnet" {
  source  = "Azure/vnet/azurerm"
  version = "5.0.1"

  resource_group_name = azurerm_resource_group.example.name
  vnet_location       = var.location
  
  # Basic network configuration
  vnet_name           = "vnet-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  
  # Empty subnet lists - we'll create subnets using a different module with for_each
  subnet_names        = []
  subnet_prefixes     = []

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}
```

### 5. Use the AVM Network Module with for_each for Subnets

Add the following to your `main.tf` file to create multiple subnets using `for_each`:

```hcl
# Random string for uniqueness
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

# Using a module with for_each to create multiple subnets
module "avm_vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.8.1"
  
  # Basic VNet configuration
  enable_telemetry    = false
  name                = "vnet-main-${random_string.suffix.result}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name
  
  # Here's the for_each on subnets
  subnets = {
    for name, prefix in var.subnets : name => {
      name             = "snet-${name}"
      address_prefixes = [prefix]
    }
  }
  
  tags = {
    Environment = var.environment
    Terraform   = "true"
    ModuleDemo  = "true"
  }
}
```

### 6. Create Outputs

Create an `outputs.tf` file with the following output blocks:

```hcl
output "vnet_id" {
  description = "The ID of the basic Virtual Network"
  value       = module.vnet.vnet_id
}

output "vnet_name" {
  description = "The name of the basic Virtual Network"
  value       = module.vnet.vnet_name
}

output "avm_vnet_id" {
  description = "The ID of the AVM Virtual Network"
  value       = module.avm_vnet.resource.id
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.example.id
}
```

### 7. Initialize the Working Directory

Initialize Terraform to download the modules:

```bash
terraform init
```

Notice how Terraform:
- Downloads the modules from the Terraform Registry
- Places the modules under the `.terraform` directory

### 8. Apply the Configuration

Plan and apply the infrastructure:

```bash
terraform plan
terraform apply
```

Observe how Terraform:
- Creates a Resource Group
- Creates a basic Virtual Network using one module
- Creates another VNet with multiple subnets using for_each with the module
- Creates a Network Security Group and associates it with one of the subnets
- Successfully references outputs between different modules

### 9. Clean Up

When you're finished, clean up the resources:

```bash
terraform destroy
```

## Understanding Module Usage

Here are the key concepts demonstrated in this lab:

### Basic Module Usage
```hcl
module "vnet" {
  source  = "Azure/vnet/azurerm"
  version = "5.0.1"
  
  resource_group_name = azurerm_resource_group.example.name
  vnet_location       = var.location
  vnet_name           = "vnet-${var.environment}"
  address_space       = ["10.0.0.0/16"]
}
```
- The `source` attribute specifies where to find the module
- The `version` attribute pins the module to a specific version
- Other attributes are inputs to the module

### Using `for_each` with Modules
```hcl
subnets = {
  for name, prefix in var.subnets : name => {
    name             = "snet-${name}"
    address_prefixes = [prefix]
  }
}
```
- This creates a subnet for each entry in the variable
- Each subnet gets unique properties based on the map key and value

### Module Outputs
```hcl
subnet_ids = [module.avm_vnet.subnet_ids["web"]]
```
- One module can reference outputs from another module
- This enables building complex infrastructure with interdependent components

## Additional Resources

- [Terraform Registry](https://registry.terraform.io/)
- [Azure Virtual Network Module](https://registry.terraform.io/modules/Azure/vnet/azurerm/latest)
- [Azure AVM Virtual Network Module](https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/latest)
- [Azure Network Security Group Module](https://registry.terraform.io/modules/Azure/network-security-group/azurerm/latest)