provider "azurerm" {
  features {}
}

# Use existing Resource Group
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Tags to be used by resources
locals {
  project_tags {
    Project = "udacity-cloud-lab"
    Assignment = "web-server-deployment"
  }
}

# Packer-built image
data "azurerm_image" "packer" {
  name                = "ubuntu1804-image"
  resource_group_name = "Azuredevops"
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/22"]
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = locals.project_tags
}

# Subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = locals.project_tags

  # Allow inbound traffic from virtual network
  security_rule {
    name                       = "Allow-VNet-Inbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow outbound traffic for virtual network 
  security_rule {
    name                       = "Allow-VNet-Outbound"
    priority                   = 201
    direction                  = "Outbound"
    access                     = "Allow" 
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"

  }

# Allow load balancer traffic to reach HTTP port 80 on VMs 
  security_rule{
    name = "Allow-HTTP-From-LoadBalancer-To-VMs"
    priority = 202 
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

# Deny all other traffic from the internet 
  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     ="*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"

  }

}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-pip"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  allocation_method = "Static"

  tags = locals.project_tags
}

# Load Balancer
resource "azurerm_lb" "main" {
  name                = "${var.prefix}-lb"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = locals.project_tags

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

# Backend Pool
resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "backendpool"
}

# Availability Set
resource "azurerm_availability_set" "main" {
  name                = "${var.prefix}-avset"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  managed = true

  tags = locals.project_tags
}

# Network Interfaces
resource "azurerm_network_interface" "main" {
  count = var.vm_count

  name                = "${var.prefix}-nic-${count.index}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = locals.project_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Associate NICs with Load Balancer Backend Pool
resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count = var.vm_count

  network_interface_id    = azurerm_network_interface.main[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}

# Virtual Machines
resource "azurerm_linux_virtual_machine" "main" {
  count = var.vm_count

  name                = "${var.prefix}-vm-${count.index}"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  tags = locals.project_tags

  size                            = "Standard_D2s_v3"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  availability_set_id = azurerm_availability_set.main.id

  network_interface_ids = [
    azurerm_network_interface.main[count.index].id
  ]

  source_image_id = data.azurerm_image.packer.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}