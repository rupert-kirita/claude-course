# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.azure_location

  tags = {
    Name        = "${var.prefix}-rg"
    Environment = var.environment
    Lab         = var.lab_name
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
    Lab         = var.lab_name
  }
}

# Subnet
resource "azurerm_subnet" "app" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

# Route Table
resource "azurerm_route_table" "main" {
  name                = "${var.prefix}-rt"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = {
    Name        = "${var.prefix}-rt"
    Environment = var.environment
    Lab         = var.lab_name
  }
}

# Network Security Group
resource "azurerm_network_security_group" "web" {
  name                = "${var.prefix}-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = {
    Name        = "${var.prefix}-nsg"
    Environment = var.environment
    Lab         = var.lab_name
  }
}
