# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "primary-resources"
  location = "eastus"

  tags = {
    Environment = "Development"
  }
}

# Virtual Networks created with count
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

# Subnets created with count
resource "azurerm_subnet" "subnet_count" {
  count                = 3
  name                 = "subnet-count-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet_count[0].name
  address_prefixes     = ["10.0.${count.index + 1}.0/24"]
}

# Network Security Groups created with count
resource "azurerm_network_security_group" "nsg_count" {
  count               = 3
  name                = "nsg-count-${count.index + 1}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "rule-${count.index + 1}"
    priority                   = 100 + count.index
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(80 + count.index * 1000)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Development"
    Type        = "NSG-${count.index + 1}"
  }
}