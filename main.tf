terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
#backend configuration
  backend "azurerm" {
    resource_group_name  = "2-tier-group-eastus"
    storage_account_name = "anasstorageaccount"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

#Resource group
data "azurerm_resource_group" "rg" {
  name     = "2-tier-group-eastus"
}

#virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

#web subnet
resource "azurerm_subnet" "web_subnet" {
  name                 = "web_Subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

#db subnet
resource "azurerm_subnet" "db_subnet" {
  name                 = "db_Subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

#NSG for web subnet
resource "azurerm_network_security_group" "web_nsg" {
  name                = "web_nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web_assoc" {
  subnet_id                 = azurerm_subnet.web_subnet.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

#NSG for db subnet
resource "azurerm_network_security_group" "db_nsg" {
  name                = "db_nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-web-to-db"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-all"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  } 
}

resource "azurerm_subnet_network_security_group_association" "db_assoc" {
  subnet_id                 = azurerm_subnet.db_subnet.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
  }

#Public IP & Load Balancer for web tier
resource "azurerm_public_ip" "web_public_ip" {
  name                = "web_public_ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones              = ["1", "2"]
}

resource "azurerm_lb" "web_lb" {
  name                = "web_lb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "web_frontend"
    public_ip_address_id = azurerm_public_ip.web_public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "web_backend_pool" {
  name                = "web_backend_pool"
  loadbalancer_id     = azurerm_lb.web_lb.id
}
  
resource "azurerm_lb_probe" "web_lb_probe" {
  name                = "web_lb_probe"
  loadbalancer_id     = azurerm_lb.web_lb.id
  port                = 80
}

resource "azurerm_lb_rule" "web_lb_rule" {
  name                           = "web_lb_rule"
  loadbalancer_id                = azurerm_lb.web_lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.web_lb.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_backend_pool.id]
  probe_id                       = azurerm_lb_probe.web_lb_probe.id
}
  
#dedicated public IPs for direct ssh access to web and db VMs
resource "azurerm_public_ip" "web_vm_public_ip" {
  count               = 2
  name                = "web_vm_public_ip-${count.index + 1}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones              = [tostring(count.index + 1)]
}

#Network Interfaces (Attached to Load Balancer Pool + Dedicated SSH IP)
resource "azurerm_network_interface" "web_vm_nic" {
  count               = 2
  name                = "web_vm_nic-${count.index + 1}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web_vm_public_ip[count.index].id
  }
}   

resource "azurerm_network_interface_backend_address_pool_association" "web_nic_backend_assoc" {
  count                  = 2
  network_interface_id    = azurerm_network_interface.web_vm_nic[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_backend_pool.id
}

#multi-zone Vms
resource "azurerm_linux_virtual_machine" "web_vm" {
  count               = 2
  name                = "web_vm-${count.index + 1}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  zone                = tostring(count.index + 1)

  network_interface_ids = [
    azurerm_network_interface.web_vm_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("${path.module}/keys/id_rsa.pub")
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

  custom_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y nginx
              echo "<h1>HA Cluster | Server: web-vm-${count.index + 1} | Zone: ${count.index + 1}</h1>" | sudo tee /var/www/html/index.html
              sudo systemctl enable --now nginx
              EOF
  )
}