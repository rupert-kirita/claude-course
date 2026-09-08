# LAB-12-AZURE: Managing Resource Lifecycles with lifecycle Meta-Argument

## Overview
This lab demonstrates how to use Terraform's `lifecycle` meta-argument to control the creation, update, and deletion behavior of Azure resources. You'll learn how to prevent resource destruction, create resources before destroying old ones, and ignore specific changes.

[![Lab 12](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

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
15 minutes

## Existing Configuration Files

The lab directory contains the following initial files:

 - `variables.tf`
 - `providers.tf`
 - `main.tf`


## Lab Steps

### 1. Initialize Terraform

Initialize your Terraform workspace:
```bash
terraform init
```

### 2. Examine the Initial Configuration

Notice the resources in `main.tf` do not have any **lifecycle** configuration.

### 3. Run an Initial Apply

Create the initial resources:
```bash
terraform plan
terraform apply
```

### 4. Add prevent_destroy Lifecycle Configuration

Add a new resource group configuration:

```hcl
# Resource Group with prevent_destroy
resource "azurerm_resource_group" "protected" {
  name     = "rg-protected-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    Purpose     = "Protected"
  }
}
```

Modify the resource block and add the `prevent_destroy` lifecycle configuration:

```hcl
# Resource Group with prevent_destroy
resource "azurerm_resource_group" "protected" {
  name     = "rg-protected-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    Purpose     = "Protected"
  }

  lifecycle {                      # <--- add this lifecycle block here (all 3 lines)
    prevent_destroy = true
  }
}
```
### 5. Apply the Changes

Apply the configuration to create the protected resource group:
```bash
terraform apply
```

### 6. Try to Destroy the Protected Resource Group

Run the command `terraform destroy -target="azurerm_resource_group.protected"` to destroy ONLY the new resource group.

Terraform should prevent you from destroying the protected resource group. You should get a similar error as shown below:

```bash
Error: Instance cannot be destroyed
│ 
│   on main.tf line 27:
│   27: resource "azurerm_resource_group" "protected" {
│ 
│ Resource azurerm_resource_group.protected has lifecycle.prevent_destroy set, but the plan calls for this resource to be destroyed. To avoid this error and continue with the plan, either disable lifecycle.prevent_destroy or reduce the
│ scope of the plan using the -target option.
```

### 7. Use the `create_before_destroy` Lifecycle Configuration

Add a storage account with the `create_before_destroy` lifecycle configuration:

```hcl
# Storage Account with create_before_destroy
resource "azurerm_storage_account" "replacement" {
  name                     = "replacesa${formatdate("YYMMDD", timestamp())}"
  resource_group_name      = azurerm_resource_group.standard.name
  location                 = azurerm_resource_group.standard.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = var.environment
    Purpose     = "Replacement"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

### 8. Apply to Create the Replacement Storage Account
```bash
terraform apply
```

### 13. Clean Up Resources

When you're done, remove the `prevent_destroy` lifecycle setting from the protected resource group first:

```hcl
# Resource Group with prevent_destroy removed
resource "azurerm_resource_group" "protected" {
  name     = "rg-protected-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    Purpose     = "Protected"
  }

  # Lifecycle block removed or modified
}
```

Then clean up all resources:
```bash
terraform apply  # Apply the removal of prevent_destroy first
terraform destroy
```

## Understanding the lifecycle Meta-Argument

### prevent_destroy
- Prevents Terraform from destroying the resource
- Useful for protecting critical resources like databases, production environments
- Must be removed before you can destroy the resource

### create_before_destroy
- Creates the replacement resource before destroying the existing one
- Useful for minimizing downtime during replacements
- Works well for resources that can exist in parallel temporarily

### ignore_changes
- Tells Terraform to ignore changes to specific attributes
- Useful when attributes are modified outside of Terraform
- Can be applied to specific attributes or all attributes with `ignore_changes = all`

### Syntax:
```hcl
resource "azurerm_example" "example" {
  # ... configuration ...
  
  lifecycle {
    prevent_destroy = true
    create_before_destroy = true
    ignore_changes = [
      tags,
      attribute_name
    ]
  }
}
```