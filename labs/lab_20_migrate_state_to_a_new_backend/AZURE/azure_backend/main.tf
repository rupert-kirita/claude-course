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
