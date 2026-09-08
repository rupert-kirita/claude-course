terraform {
  required_version = ">= 1.12.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Primary provider
provider "azurerm" {
  features {}
  alias = "primary"
}

# Secondary provider
provider "azurerm" {
  features {}
  alias = "secondary"
}