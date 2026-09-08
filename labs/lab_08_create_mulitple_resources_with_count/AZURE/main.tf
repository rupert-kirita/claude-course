# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "main-resources"
  location = "eastus"

  tags = {
    Environment = "Development"
  }
}

# Individual Virtual Networks
resource "azurerm_virtual_network" "vnet1" {
  name                = "vnet-1"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = "Development"
    Network     = "VNet1"
  }
}

resource "azurerm_virtual_network" "vnet2" {
  name                = "vnet-2"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = "Development"
    Network     = "VNet2"
  }
}

resource "azurerm_virtual_network" "vnet3" {
  name                = "vnet-3"
  address_space       = ["10.3.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = "Development"
    Network     = "VNet3"
  }
}

# Individual Subnets
resource "azurerm_subnet" "subnet1" {
  name                 = "subnet-1"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "subnet2" {
  name                 = "subnet-2"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.1.2.0/24"]
}

# Individual Network Security Groups
resource "azurerm_network_security_group" "web" {
  name                = "web-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Development"
    Role        = "Web"
  }
}

resource "azurerm_network_security_group" "app" {
  name                = "app-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-app"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Development"
    Role        = "App"
  }
}

resource "azurerm_network_security_group" "db" {
  name                = "db-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-sql"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Development"
    Role        = "DB"
  }
}