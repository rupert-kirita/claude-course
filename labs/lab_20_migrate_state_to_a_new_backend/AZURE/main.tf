# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.azure_location
  tags = {
    Name        = "${var.prefix}-rg"
    Environment = var.environment
  }
}
# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.vnet_cidr]
  tags = {
    Name        = "${var.prefix}-vnet"
    Environment = var.environment
  }
}
# Subnet
resource "azurerm_subnet" "app" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}
# Network Security Group
resource "azurerm_network_security_group" "app" {
  name                = "${var.prefix}-app-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags = {
    Name        = "${var.prefix}-app-nsg"
    Environment = var.environment
  }
}
