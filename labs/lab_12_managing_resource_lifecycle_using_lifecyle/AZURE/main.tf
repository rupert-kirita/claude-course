# Resource Group without lifecycle configuration
resource "azurerm_resource_group" "standard" {
  name     = "rg-standard-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    Purpose     = "Standard"
  }
}

# Storage Account without lifecycle configuration
resource "azurerm_storage_account" "standard" {
  name                     = "standardsa${formatdate("YYMMDD", timestamp())}"
  resource_group_name      = azurerm_resource_group.standard.name
  location                 = azurerm_resource_group.standard.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    Environment = var.environment
    Purpose     = "Standard"
  }
}