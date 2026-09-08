# LAB-08-AZ: Creating Multiple Resources with the Count Meta-Argument

## Overview
In this lab, you will learn how to use Terraform's `count` meta-argument to create multiple similar resources efficiently. You'll start with a configuration that creates individual resources and refactor it to create multiple resources using count. The lab uses Azure free-tier resources to ensure no costs are incurred.

[![Lab 08](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed
- Azure free account
- Basic understanding of Terraform and Azure concepts

Note: Azure credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each **lab** to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time
40 minutes

## Existing Configuration Files

The lab directory contains the following files with repetitive resource creation that we'll refactor using `count`:

 - `main.tf`
 - `variables.tf`
 - `providers.tf`

Examine these files and notice:
- Individual virtual network resources with similar configuration
- Repetitive subnet definitions
- Multiple security groups with similar structure
- Redundant code that could be simplified

## Lab Steps

### 1. Configure Azure Credentials

Make sure you're authenticated with Azure:

```bash
az login
```

### 2. Update Variables for Count

Modify `variables.tf` to include variables that will work with `count`:

```hcl
variable "vnet_count" {
  description = "Number of virtual networks to create"
  type        = number
  default     = 3
}

variable "vnet_address_spaces" {
  description = "Address spaces for virtual networks"
  type        = list(string)
  default     = ["10.1.0.0/16", "10.2.0.0/16", "10.3.0.0/16"]
}

variable "subnet_count" {
  description = "Number of subnets to create in the first VNet"
  type        = number
  default     = 2
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for subnets"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "nsg_configs" {
  description = "Network security group configurations"
  type = list(object({
    name         = string
    rule_name    = string
    port         = number
    source_addrs = string
  }))
  default = [
    {
      name         = "web"
      rule_name    = "allow-http"
      port         = 80
      source_addrs = "*"
    },
    {
      name         = "app"
      rule_name    = "allow-app"
      port         = 8080
      source_addrs = "10.1.0.0/16"
    },
    {
      name         = "db"
      rule_name    = "allow-sql"
      port         = 1433
      source_addrs = "10.1.0.0/16"
    }
  ]
}
```

### 3. Refactor Virtual Networks and Subnets Using `count`

Replace the individual virtual network resources with a single `count`-based resource in `main.tf`:

```hcl
# Resource Group remains the same
resource "azurerm_resource_group" "main" {
  name     = "main-resources"
  location = var.location

  tags = {
    Environment = "Development"
  }
}

# Refactored Virtual Networks using count
resource "azurerm_virtual_network" "vnet" {
  count               = var.vnet_count                           # <-- add count meta-argument here
  name                = "vnet-${count.index + 1}"                # <-- use count.index for dynamic names
  address_space       = [var.vnet_address_spaces[count.index]]   # <-- use count.index for dynamic address space
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = "Development"
    Network     = "VNet${count.index + 1}"                       # <-- use count.index for tag
  }
}
```

Next, replace the individual subnet resources with a `count`-based approach - this is required since the original `azuremrm-subnet` configurations referenced the original individual `vnet` resource blocks (which have now been changed).

```hcl
# Refactored Subnets using count
resource "azurerm_subnet" "subnet" {
  count                = var.subnet_count
  name                 = "subnet-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = [var.subnet_address_prefixes[count.index]]
}
```

Apply the changes and observe the results - notice how Terraform creates **3** x vNets because the variable `vnet_count` = `3` and then creates **2** subnets per vnet because `subnet_count` = `2`

```bash
terraform plan
terraform apply
```

### 4. Adjust VNet Count

Modify the vnet_count variable in `terraform.tfvars` (create this file) to test different VNet counts:

```hcl
vnet_count = 2
```

Apply the changes and observe the results:

```bash
terraform plan
terraform apply
```

Notice how Terraform plans to destroy one virtual network, maintaining only the number specified in the count.

### 5. Refactor Network Security Groups Using Count

Replace the individual NSG resources with a count-based approach - this one uses a much more complex variable but it's a good example to show.

```hcl
# Refactored Network Security Groups using count
resource "azurerm_network_security_group" "nsg" {
  count               = 3  # Creating 3 NSGs
  name                = "${var.nsg_configs[count.index].name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = var.nsg_configs[count.index].rule_name
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.nsg_configs[count.index].port)
    source_address_prefix      = var.nsg_configs[count.index].source_addrs
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Development"
    Role        = var.nsg_configs[count.index].name
  }
}
```

### 6. Create Outputs Using Count

Create an `outputs.tf` file to demonstrate how to reference count-based resources:

```hcl
output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "vnet_ids" {
  description = "The IDs of the virtual networks"
  value       = azurerm_virtual_network.vnet[*].id
}

output "vnet_address_spaces" {
  description = "The address spaces of the virtual networks"
  value       = azurerm_virtual_network.vnet[*].address_space
}

output "subnet_ids" {
  description = "The IDs of the subnets"
  value       = azurerm_subnet.subnet[*].id
}

output "nsg_ids" {
  description = "The IDs of the network security groups"
  value       = azurerm_network_security_group.nsg[*].id
}
```

### 7. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Understanding Count

Let's examine how count improves your Terraform configurations:

### Basic Count Usage
- `count = N` creates N instances of a resource
- `count.index` provides the current index (0 to N-1)
- Each resource instance gets a unique index

### Resource References
- Individual resource: `azurerm_virtual_network.vnet[0]`
- All resources: `azurerm_virtual_network.vnet[*]`
- Specific attribute of all resources: `azurerm_virtual_network.vnet[*].id`

### Count with Variables
- Using list variables with count.index
- Controlling count with number variables
- Creating related resources with similar counts

### Limitations
- Resources must be identical except for elements that use count.index
- Changing the count can cause resource recreation
- Removing an element from the middle of a list can affect multiple resources

## Additional Exercises

1. Create multiple storage accounts using count
2. Create a different number of subnets for each virtual network
3. Try creating multiple resource groups with count
4. Add subnet-NSG associations using count

## Common Issues and Solutions

1. **Index Out of Range**
   - Ensure list variables have at least as many elements as the count value
   - Be careful when referencing list elements with count.index

2. **Resource Recreation**
   - Be cautious when changing count on existing infrastructure
   - Adding or removing elements can affect resource IDs

3. **Resource References**
   - Always use the [index] or [*] notation when referencing count resources
   - Remember that the index starts at 0, not 1