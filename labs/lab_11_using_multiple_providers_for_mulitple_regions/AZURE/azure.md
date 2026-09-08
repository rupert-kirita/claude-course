# LAB-11-AZURE: Deploying Resources to Multiple Regions

## Overview
This lab demonstrates how to use multiple provider blocks in Terraform to deploy resources to different Azure regions simultaneously. You'll create resources in two regions using a simple, free configuration.

[![Lab 11](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml/badge.svg?branch=main)](https://github.com/btkrausen/terraform-testing/actions/workflows/azure_lab_validation.yml)

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
10 minutes

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

### 2. Examine the Provider Configuration

Notice how the `provider` blocks are configured in `providers.tf`:
- The primary provider with an alias of "primary"
- The secondary provider with an alias of "secondary"

> Note to keep this lab simple, I didn't add any specific configurations to the providers. However, normally you could add unique configurations for each, such as a different subscription_id to deploy resources to a different subscription. This was done because Azure provider doesn't support regions within the provider itself like other providers do.

### 3. Examine the Resource Configuration

Look at how resources specify which provider to use:
- `provider = azurerm.primary` for resources in the primary region
- `provider = azurerm.secondary` for resources in the secondary region

### 4. Run Plan and Apply

Create the resources in both regions:
```bash
terraform plan
terraform apply
```

### 5. Add a Container to Each Storage Account

Add the following resources to `main.tf`:

```hcl
# Storage Container in primary region
resource "azurerm_storage_container" "primary" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.primary.id
  container_access_type = "private"
}

# Storage Container in secondary region
resource "azurerm_storage_container" "secondary" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.secondary.id
  container_access_type = "private"
}
```

Add the `provider` configuration to each of the blocks to specify what provider alias to use for each resource:

```hcl
# Storage Container in primary region
resource "azurerm_storage_container" "primary" {
  provider              = azurerm.primary                      # <--- add this line here
  name                  = "data"
  storage_account_id    = azurerm_storage_account.primary.id
  container_access_type = "private"
}

# Storage Container in secondary region
resource "azurerm_storage_container" "secondary" {
  provider              = azurerm.secondary                    # <--- add this line here
  name                  = "data"
  storage_account_id    = azurerm_storage_account.secondary.id
  container_access_type = "private"
}
```

### 6. Apply the Changes

Apply the configuration to create the containers:
```bash
terraform apply
```

### 7. Create outputs.tf

Create an outputs.tf file:

```hcl
output "primary_resource_group_name" {
  description = "Name of the resource group in the primary region"
  value       = azurerm_resource_group.primary.name
}

output "secondary_resource_group_name" {
  description = "Name of the resource group in the secondary region"
  value       = azurerm_resource_group.secondary.name
}

output "primary_storage_account_name" {
  description = "Name of the storage account in the primary region"
  value       = azurerm_storage_account.primary.name
}

output "secondary_storage_account_name" {
  description = "Name of the storage account in the secondary region"
  value       = azurerm_storage_account.secondary.name
}
```

### 8. Apply to See Outputs
```bash
terraform apply
```

### 9. Clean Up Resources

When you're done, clean up all resources:
```bash
terraform destroy
```

## Understanding Multiple Provider Configuration

### Provider Aliases
- Provider aliases allow you to define multiple configurations for the same provider
- Each provider block can have its own configuration (location, credentials, etc.)
- Use the `alias` attribute to name each provider configuration

### Specifying Providers for Resources
- Use the `provider` attribute in resource blocks to specify which provider to use
- Format is `provider = azurerm.<alias>`
- If no provider is specified, the default provider (without an alias) is used

### Common Multi-Region Scenarios
- Disaster recovery across regions
- Deploying to multiple regions for reduced latency
- Creating resources that need to interact across regions