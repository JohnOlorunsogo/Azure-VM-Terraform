terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "yj-rg" {
  name     = "yj-resource-group"
  location = "East US"

  tags = {
    environment = "dev"
  }
}

# Create a virtual network 
resource "azurerm_virtual_network" "yj-vnet" {
  name                = "yj-virtual-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.yj-rg.location
  resource_group_name = azurerm_resource_group.yj-rg.name

  tags = {
    environment = "dev"
  }
}

# Create a subnet
resource "azurerm_subnet" "yj-subnet" {
  name                 = "yj-subnet"
  resource_group_name  = azurerm_resource_group.yj-rg.name
  virtual_network_name = azurerm_virtual_network.yj-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create a public IP address
resource "azurerm_public_ip" "yj-public-ip" {
  count               = var.vm_count
  name                = "yj-public-ip-${count.index}"
  location            = azurerm_resource_group.yj-rg.location
  resource_group_name = azurerm_resource_group.yj-rg.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

# Create a network interface
resource "azurerm_network_interface" "yj-nic" {
  count               = var.vm_count
  name                = "yj-nic-${count.index}"
  location            = azurerm_resource_group.yj-rg.location
  resource_group_name = azurerm_resource_group.yj-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.yj-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.yj-public-ip[count.index].id
  }


  tags = {
    environment = "dev"
  }
}

# Create a network security group
resource "azurerm_network_security_group" "yj-nsg" {
  name                = "yj-nsg"
  location            = azurerm_resource_group.yj-rg.location
  resource_group_name = azurerm_resource_group.yj-rg.name

  tags = {
    environment = "dev"
  }
}

# Create a security rule to allow SSH access 
resource "azurerm_network_security_rule" "yj-ssh-rule" {
  name                        = "SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.yj-rg.name
  network_security_group_name = azurerm_network_security_group.yj-nsg.name
}

# Create a security rule to allow HTTP access
resource "azurerm_network_security_rule" "yj-http-rule" {
  name                        = "AllowHTTP"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.yj-rg.name
  network_security_group_name = azurerm_network_security_group.yj-nsg.name
}


# Associate the network security group with the network interface
resource "azurerm_network_interface_security_group_association" "yj-nic-nsg-association" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.yj-nic[count.index].id
  network_security_group_id = azurerm_network_security_group.yj-nsg.id
}

# Create a virtual machine
resource "azurerm_linux_virtual_machine" "yj-vm" {
  count               = var.vm_count
  name                = "yj-vm-${count.index}"
  resource_group_name = azurerm_resource_group.yj-rg.name
  location            = azurerm_resource_group.yj-rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.yj-nic[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.public_key_path)
  }


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    environment = "dev"
  }
}
