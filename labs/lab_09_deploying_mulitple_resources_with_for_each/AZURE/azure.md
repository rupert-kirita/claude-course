# LAB-09-AZ: Creating and Managing Resources with the For_Each Meta-Argument

## Overview
In this lab, you will learn how to use Terraform's `for_each` meta-argument to create and manage multiple resources efficiently. You'll discover how `for_each` differs from `count` and when to use each approach. The lab uses Azure free-tier resources to ensure no costs are incurred.

[![Lab 09](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

**Preview Mode**: Use `Cmd/Ctrl + Shift + V` in VSCode to see a nicely formatted version of this lab!

## Prerequisites
- Terraform installed
- Azure free account
- Basic understanding of Terraform and Azure concepts
- Familiarity with the `count` meta-argument

Note: Azure credentials are required for this lab.

## How to Use This Hands-On Lab

1. **Create a Codespace** from this repo (click the button below).  
2. Once the Codespace is running, open the integrated terminal.
3. Follow the instructions in each **lab** to complete the exercises.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/btkrausen/terraform-codespaces)

## Estimated Time
45 minutes

## Existing Configuration Files

The lab directory contains the following files with resources created using `count` that we'll refactor to use `for_each`:

 - `main.tf`
 - `variables.tf`
 - `providers.tf`

Examine these files and notice:
- Virtual network creation using count and list indexing
- Subnet resources using count and referencing a virtual network with index
- Network security groups with dynamic security rules based on count
- The potential issues if list elements are reordered or removed

## Lab Steps

### 1. Configure Azure Credentials

Make sure you're authenticated with Azure:

```bash
az login
```

### 2. Update Variables that will be used with our `for_each`

Modify `variables.tf` to include map variables for use with for_each:

```hcl
variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "eastus"
}

# Keep the list variables for comparison
variable "vnet_cidr_blocks" {
  description = "CIDR blocks for virtual networks"
  type        = list(string)
  default     = ["10.0.0.0/16", "10.1.0.0/16", "10.2.0.0/16"]
}

# New map variables for for_each
variable "vnet_config" {
  description = "Map of virtual network configurations"
  type        = map(string)
  default = {
    "production" = "10.0.0.0/16"
    "staging"    = "10.1.0.0/16"
    "development" = "10.2.0.0/16"
  }
}

variable "subnet_config" {
  description = "Map of subnet configurations"
  type        = map(string)
  default = {
    "web"  = "10.0.1.0/24"
    "app"  = "10.0.2.0/24"
    "data" = "10.0.3.0/24"
  }
}

variable "nsg_ports_map" {
  description = "Map of NSG ports"
  type        = map(number)
  default = {
    "http"    = 80
    "https"   = 443
    "app"     = 8080
    "db"      = 3306
  }
}
```

### 3. Keep Count-Based Resources

Leave the Azure Resource Group and count-based resources in place for comparison:

```hcl
# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "main-resources"
  location = var.location

  tags = {
    Environment = "Development"
  }
}

# Virtual Networks created with count (for comparison)
resource "azurerm_virtual_network" "vnet_count" {
  count               = 3
  name                = "vnet-count-${count.index + 1}"
  address_space       = ["10.${count.index}.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = "Development"
    Network     = "Network-${count.index + 1}"
  }
}
```

### 4. Add Virtual Network Resources Using For_Each

Add new virtual network resources using for_each to `main.tf`:

```hcl
# Virtual Networks created with for_each
resource "azurerm_virtual_network" "vnet_foreach" {
  for_each            = var.vnet_config
  name                = "vnet-${each.key}"
  address_space       = [each.value]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = "Development"
    Network     = "Network-${each.key}"
  }
}
```

### 5. Apply and Compare Virtual Networks

Initialize and apply the configuration:

```bash
terraform fmt
terraform init
terraform plan
terraform apply
```

Compare the count-based and for_each-based virtual networks in the Azure Portal:
- Notice how the for_each virtual networks have meaningful names based on map keys
- Observe how the resources are referenced differently in the state file

### 6. Add Subnet Resources Using For_Each

Add new subnet resources using for_each:

```hcl
# Subnets created with for_each
resource "azurerm_subnet" "subnet_foreach" {
  for_each             = var.subnet_config
  name                 = "subnet-${each.key}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet_foreach["production"].name
  address_prefixes     = [each.value]
}
```

Apply the configuration:

```bash
terraform plan
terraform apply
```

### 7. Add Network Security Group Resources Using For_Each

Add new network security group resources using for_each:

```hcl
# Network Security Groups created with for_each
resource "azurerm_network_security_group" "nsg_foreach" {
  for_each            = var.nsg_ports
  name                = "nsg-${each.key}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-${each.key}"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${each.value}"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Development"
    Service     = each.key
  }
}
```

Try to apply the configuration:

```bash
terraform plan
terraform apply
```

> Tricked you! Notice that the Network Security Groups block is using the `var.nsg_ports` variable, which is our _original_ variable that is a `list`, not a `map`. Remember that **for_each** doesn't work with lists, so we need to use our newer variable of `var.nsg_ports_map`.

Change the resource block to use `var.nsg_ports_map` instead:

```hcl
# Network Security Groups created with for_each
resource "azurerm_network_security_group" "nsg_foreach" {
  for_each            = var.nsg_ports_map                      # <-- change it here
  name                = "nsg-${each.key}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  ...
```
Apply the configuration:

```bash
terraform plan
terraform apply
```

### 8. Create Simple Route Tables with For_Each

Create a simple map for route tables in the `variables.tf` file:

```hcl
variable "route_tables" {
  description = "Map of route tables to create"
  type        = map(string)
  default = {
    "public"   = "Internet-facing routes"
    "private"  = "Internal-only routes"
    "gateway"  = "Gateway routes"
  }
}
```

Add route table resources using `for_each` in the `main.tf` file:

```hcl
# Route tables created with for_each
resource "azurerm_route_table" "rt_foreach" {
  for_each            = var.route_tables
  name                = "rt-${each.key}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = "Development"
    Description = each.value
  }
}
```

Apply the configuration:

```bash
terraform plan
terraform apply
```

### 9. Create Outputs for For_Each Resources

Create an `outputs.tf` file to reference `for_each`-based resources:

```hcl
output "vnet_count_ids" {
  description = "The IDs of the count-based virtual networks"
  value       = azurerm_virtual_network.vnet_count
}

output "vnet_foreach_ids" {
  description = "The IDs of the for_each-based virtual networks"
  value       = azurerm_virtual_network.vnet_foreach
}

output "subnet_foreach_ids" {
  description = "The IDs of the for_each-based subnets"
  value       = azurerm_subnet.subnet_foreach
}

output "nsg_foreach_ids" {
  description = "The IDs of the for_each-based NSGs"
  value       = azurerm_network_security_group.nsg_foreach
}

output "route_table_ids" {
  description = "The IDs of the for_each-based route tables"
  value       = azurerm_route_table.rt_foreach
}
```

Apply to see the outputs:

```bash
terraform apply
```

### 10. Experiment by Modifying Resources

Let's demonstrate the advantage of `for_each` when removing or renaming resources:

1. Modify the `vnet_config` variable to remove **one** virtual network:

```hcl
variable "vnet_config" {
  description = "Map of virtual network configurations"
  type        = map(string)
  default = {
    "production" = "10.0.0.0/16"
    "development" = "10.2.0.0/16"
    # Removed "staging" virtual network
  }
}
```

2. Also modify the `vnet_cidr_blocks` list to remove an element:

```hcl
variable "vnet_cidr_blocks" {
  description = "CIDR blocks for virtual networks"
  type        = list(string)
  default     = ["10.0.0.0/16", "10.2.0.0/16"] # Removed the second element
}
```

Apply the changes and observe the differences:

```bash
terraform plan
```

Notice how:
- With `count`, removing the middle element shifts all indexes, potentially recreating resources
- With `for_each`, only the specific "staging" virtual network is removed, leaving others untouched

### 11. Add a New Resource to Existing Map

Add a new entry to the `nsg_ports_map` variable:

```hcl
variable "nsg_ports_map" {
  description = "Map of NSG ports"
  type        = map(number)
  default = {
    "http"    = 80
    "https"   = 443
    "app"     = 8080
    "db"      = 3306
    "redis"   = 6379 # Added new entry
  }
}
```

Apply the changes:

```bash
terraform plan
terraform apply
```

Notice how only the new resource is added without affecting existing ones.

### 12. Clean Up

Remove all created resources:

```bash
terraform destroy
```

## Understanding For_Each

Let's examine how for_each improves your Terraform configurations:

### For_Each vs Count
- **For_Each**: Resources are indexed by key (string) instead of numeric index
- **Count**: Resources are indexed by position (0, 1, 2, ...)

### For_Each Advantages
- Resources maintain stable identity when items are added or removed
- Keys provide meaningful naming in state and Azure Portal
- More expressive and clear configuration
- Better handles non-uniform resource configurations

### For_Each Usage
- Can use a map with string keys
- With a basic map of strings: `for_each = var.vnet_config`
- With a map of numbers: `for_each = var.nsg_ports`

### Resource References
- Referencing a specific resource: `azurerm_virtual_network.vnet_foreach["production"]`
- Referencing a value from a specific resource: `azurerm_virtual_network.vnet_foreach["production"].id`
- Outputting all resources: `azurerm_virtual_network.vnet_foreach`

## Additional Exercises

1. Create multiple storage accounts with for_each
2. Add subnet-NSG associations using for_each
3. Create different network interfaces for each subnet
4. Try creating multiple resource groups with for_each

## Common Issues and Solutions

1. **Invalid for_each Value**
   - For_each value must be a map or set of strings
   - Map values must be known at plan time

2. **Key Type Errors**
   - For_each keys must be strings
   - Numeric keys in maps should be quoted

3. **Resource References**
   - Access for_each resources with square brackets and the key
   - Don't use numeric indexes (like with count)