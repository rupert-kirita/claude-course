# LAB-13-Azure: Using Basic Terraform Functions

## Overview
In this lab, you will learn how to use a few essential Terraform built-in functions: `min`, `max`, `join`, and `toset`. These functions help you manipulate values and create more flexible infrastructure configurations. The lab uses Azure free-tier resources to ensure minimal or no costs are incurred.

[![Lab 13](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed (v1.0.0+)
- Azure free tier account
- Azure CLI installed and configured
- Basic understanding of Terraform and Azure concepts

Note: Azure credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each section to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/your-username/terraform-azure-lab)

## Estimated Time
20 minutes

## Initial Configuration Files

The lab directory will contain the following files:

 - `main.tf` - Main configuration file for Azure resources
 - `variables.tf` - Variable definitions
 - `providers.tf` - Provider configuration
 - `outputs.tf` - Output definitions

## Lab Steps

### 1. Configure Azure Credentials

First, login to Azure using the Azure CLI:

```bash
az login
```

This will open a browser window where you can authenticate with your Azure account.

### 2. Create the Providers Configuration

Open the `providers.tf` file and add the following configurations:

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
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

### 3. Set Up Variables

Modify the `variables.tf` file and add the following variable definitions:

```hcl
variable "locations" {
  description = "List of Azure regions"
  type        = list(string)
  default     = ["eastus", "westus", "centralus"]
}

variable "address_spaces" {
  description = "Address spaces for virtual networks"
  type        = list(string)
  default     = ["10.0.0.0/16", "10.1.0.0/16", "10.2.0.0/16"]
}

variable "subnet_prefixes" {
  description = "Subnet address prefixes"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
}

variable "teams" {
  description = "List of teams (with duplicates)"
  type        = list(string)
  default     = ["dev", "ops", "dev", "security", "data", "ops"]
}
```

### 4. Create a Resource Group with Join Function

Create a `main.tf` file and add a resource group that uses a static string for the `name`:

```hcl
# Random string to ensure uniqueness
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Use join function to create a resource group name
resource "azurerm_resource_group" "main" {
  name     = "rg-dev"
  location = var.location

  tags = {
    Environment = var.environment
    Purpose     = "Terraform Function Lab"
  }
}
```

Now, update the `name` argument to use the `join` function instead of a static string to be more dynamic:

```hcl
# Use join function to create a resource group name
resource "azurerm_resource_group" "main" {
  name     = join("-", [var.environment, "rg", random_string.suffix.result])        # <-- change this line
  location = var.location

  tags = {
    Environment = var.environment
    Purpose     = "Terraform Function Lab"
  }
}
```

### 5. Use `min` Function for Virtual Network Count

Add virtual network resources using the `min` function:

```hcl
resource "azurerm_virtual_network" "main" {
  count               = 3
  name                = "${var.environment}-vnet-${count.index + 1}"
  location            = var.locations[count.index]
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.address_spaces[count.index]]

  tags = {
    Name = "${var.environment}-vnet-${count.index + 1}"
  }
}
```

Now, let's add some error handling to ensure we don't try to create more networks than we have address spaces. Modify the `azurerm_virtual_network` resource to use the `min` function:

```hcl
# Use min function to determine how many virtual networks to create
# This ensures we don't try to create more networks than we have address spaces
resource "azurerm_virtual_network" "main" {
  count               = min(length(var.locations), length(var.address_spaces))        # <-- change this line
  name                = "${var.environment}-vnet-${count.index + 1}"
  location            = var.locations[count.index]
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.address_spaces[count.index]]

  tags = {
    Name = "${var.environment}-vnet-${count.index + 1}"
  }
}
```
### 6. Use `toset` Function to Remove Potential Duplicates from a List of Strings

Create a Network Security Group with tags based on unique team names:

```hcl
# Use toset function to remove duplicates from teams list
locals {
  unique_teams = toset(var.teams)
}

# Create Network Security Group
resource "azurerm_network_security_group" "example" {
  name                = "${var.environment}-nsg-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Name  = "${var.environment}-nsg"
    Teams = join(", ", local.unique_teams)
    # This joins unique team names with commas
  }
}
```

### 7. Add Outputs

Create an `outputs.tf` file with outputs:

```hcl
output "resource_group_id" {
  description = "The ID of the Resource Group"
  value       = azurerm_resource_group.main.id
}

output "vnet_count" {
  description = "Number of virtual networks created (using min function)"
  value       = min(length(var.locations), length(var.address_spaces))
}

output "unique_teams" {
  description = "List of unique teams (using toset function)"
  value       = local.unique_teams
}
```

### 10. Apply the Configuration

Initialize and apply the configuration:

```bash
terraform init
terraform plan
terraform apply
```

Observe how the functions work:
- `join` creates string values by combining elements
- `min` calculates the minimum value between two numbers
- `toset` converts a list to a set, removing duplicates
- `max` returns the maximum value from a set of numbers

### 11. Clean Up

When finished, remove all created resources:

```bash
terraform destroy
```

## Function Reference

### Join Function
The `join` function combines a list of strings with a specified delimiter.
```
join(separator, list)
```
Example: `join("-", ["dev", "rg"])` produces `"dev-rg"`

### Min Function
The `min` function returns the minimum value from a set of numbers.
```
min(number1, number2, ...)
```
Example: `min(3, 5)` produces `3`

### Max Function
The `max` function returns the maximum value from a set of numbers.
```
max(number1, number2, ...)
```
Example: `max(3, 5)` produces `5`

### Toset Function
The `toset` function converts a list to a set, removing any duplicate elements.
```
toset(list)
```
Example: `toset(["dev", "ops", "dev", "security"])` produces `["dev", "ops", "security"]`

## Extra Challenge Exercises

1. Use the `concat` function to combine two lists of team names
2. Use the `lookup` function to set conditional tags based on environment
3. Use the `coalesce` function to provide a default value if a variable is empty
4. Create a more complex naming convention using multiple `join` functions

## Notes on Azure Free Resources

All resources used in this lab are part of the Azure Free Tier or incur minimal cost:
- Resource Groups are free
- Virtual Networks have no cost
- Network Security Groups have no cost in small numbers
- Storage Accounts have a free tier with limited storage