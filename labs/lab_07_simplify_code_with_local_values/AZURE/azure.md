# LAB-07-AZ: Simplifying Code with Local Values

## Overview
In this lab, you will learn how to use Terraform's `locals` blocks to refactor repetitive code, create computed values, and make your configurations more dynamic. You'll take an existing configuration with redundant elements and improve it by centralizing common values and creating more maintainable infrastructure code.

[![Lab 07](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed
- Azure free tier account
- Basic understanding of Terraform and Azure concepts

Note: Azure credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each **lab** to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time
30 minutes

## Existing Configuration Files

The lab directory contains the following files with repetitive code that we'll refactor:

 - `main.tf`
 - `variables.tf`
 - `providers.tf`

Examine these files and notice:
- Repeated tag values across multiple resources
- Redundant naming patterns
- Hardcoded values that could be computed
- No centralized management of common elements

## Lab Steps

### 1. Configure Azure Credentials

Make sure you're authenticated with Azure:

```bash
az login
```

### 2. Add Data Sources

Add the following data source to the top of `main.tf`:

```hcl
# Get subscription information
data "azurerm_subscription" "current" {}
```

### 3. Create Locals Block

Add a locals block at the top of `main.tf` (after the data source):

```hcl
locals {
  # Common tags for all resources
  tags = {
    Environment  = var.environment
    Project      = "terraform-demo"
    Owner        = "infrastructure-team"
    CostCenter   = "cc-1234"
    Region       = var.location
    ManagedBy    = "terraform"
    Subscription = data.azurerm_subscription.current.display_name
  }
  
  # Common name prefix for resources
  name_prefix = "${var.environment}-"
}
```

### 4. Refactor Resources

Replace the resources in `main.tf` with these refactored versions:

```hcl
resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}resources"
  location = var.location

  tags = {
    Name         = "${local.name_prefix}resources"
    Environment  = local.tags.Environment
    Project      = local.tags.Project
    Owner        = local.tags.Owner
    CostCenter   = local.tags.CostCenter
    Region       = local.tags.Region
    ManagedBy    = local.tags.ManagedBy
    Subscription = local.tags.Subscription
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = var.vnet_address_space

  tags = {
    Name        = "${local.name_prefix}vnet"
    Environment = local.tags.Environment
    Project     = local.tags.Project
    Owner       = local.tags.Owner
    CostCenter  = local.tags.CostCenter
    Region      = local.tags.Region
    ManagedBy   = local.tags.ManagedBy
    Subscription = local.tags.Subscription
  }
}

resource "azurerm_subnet" "web" {
  name                 = "${local.name_prefix}web-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "app" {
  name                 = "${local.name_prefix}app-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "db" {
  name                 = "${local.name_prefix}db-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_network_security_group" "web" {
  name                = "${local.name_prefix}web-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Name        = "${local.name_prefix}web-nsg"
    Environment = local.tags.Environment
    Project     = local.tags.Project
    Owner       = local.tags.Owner
    CostCenter  = local.tags.CostCenter
    Region      = local.tags.Region
    ManagedBy   = local.tags.ManagedBy
    Subscription = local.tags.Subscription
  }
}
```

### 5. Create Outputs File

Create an `outputs.tf` file:

```hcl
output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "virtual_network_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "web_subnet_id" {
  description = "The ID of the web subnet"
  value       = azurerm_subnet.web.id
}

output "app_subnet_id" {
  description = "The ID of the app subnet"
  value       = azurerm_subnet.app.id
}

output "db_subnet_id" {
  description = "The ID of the database subnet"
  value       = azurerm_subnet.db.id
}

output "nsg_id" {
  description = "The ID of the network security group"
  value       = azurerm_network_security_group.web.id
}
```

### 6. Apply Initial Configuration

Initialize and apply the initial configuration:

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
```

Review the created resources in the Azure Portal:
- Notice the consistent naming convention based on the environment variable
- Observe how all resources have the same tag values
- Check how names are formed using the name_prefix local value

### 7. Update Locals and Observe Changes

Now, let's demonstrate the power of centralized configuration by updating our locals block:

1. Modify the `locals` block in `main.tf` to update some values:

```hcl
locals {
  # Common tags for all resources
  tags = {
    Environment = var.environment
    Project     = "terraform-improved-demo"  # <-- Changed from "terraform-demo"
    Owner       = "devops-team"              # <-- Changed from "infrastructure-team"
    CostCenter  = "cc-5678"                  # <-- Changed from "cc-1234"
    Region      = var.location
    ManagedBy   = "terraform"
    Subscription = data.azurerm_subscription.current.display_name
  }
  
  # Common name prefix for resources
  name_prefix = "${var.environment}-tf-"     # <-- Added "tf-" to the prefix
}
```

2. Create a new `terraform.tfvars` file to change the environment:

```hcl
environment = "dev"
location    = "eastus"
```

3. Apply the changes and observe the results:

```bash
terraform plan
terraform apply
```

4. Check the Azure Portal again and notice:
   - All resources have been recreated or updated
   - All resource names now include "dev-tf-" instead of "production-"
   - All tags have been updated with the new project, owner, and cost center values
   - These changes were made by modifying only the locals block and tfvars file

This demonstrates how using locals allows you to make widespread changes to your infrastructure by modifying just a few values in a central location.

### 8. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Additional Exercises

1. Add more computed values to the locals block
2. Create local variables for the subnet address prefixes instead of hardcoding them
3. Add location-specific naming to resources
4. Experiment with different environment values in terraform.tfvars