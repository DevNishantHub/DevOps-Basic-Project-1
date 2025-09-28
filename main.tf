terraform {
	required_providers{
		azurerm = {
			source = "hashicorp/azurerm"
			version = "3.1.0"
		}
	}
	required_version= "~>1.0"
}
provider "azurerm"{
	features{}
}
variable "location"{
	description = "Azure region"
	type = string
	default = "East US"
}
variable "vm_size"{
	description = "Size of virtual machine"
	type = string
	default = "Standard_B1s"
}	

variable "admin_username" {
	description = "Administrator Username"
	type = string
	default =  "azureuser"
}
variable "admin_password" {
	description = "Administrator Password"
	type = string
	default = "admin@123"
	sensitive = true
}
resource "azurerm_resource_group" "main" {
	name = "rg-vm-deploy"
	location= var.location
}
resource "azurerm_virtual_network" "main"{
	name = "vnet-demo"
	resource_group_name = azurerm_resource_group.main.name
	location = azurerm_resource_group.main.location
	address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "internal"{
	resource_group_name = azurerm_resource_group.main.name
	name = "subnet_internal"
	virtual_network_name = azurerm_virtual_network.main.name
	address_prefixes = ["10.0.2.0/24"]
}
resource "azurerm_network_security_group" "main" {
	name = "nsg-deploy"
	location = azurerm_resource_group.main.location
	resource_group_name = azurerm_resource_group.main.name

	security_rule{
		name = "SSH"
		priority = 1001
		direction = "Inbound"
		access = "Allow"
		protocol = "Tcp"
		source_port_range = "*"
		destination_port_range = "22"
		source_address_prefix = "*"
		destination_address_prefix = "*"
	}
	security_rule{
                name = "RDP"
                priority = 1002
                direction = "Inbound"
                access = "Allow"
                protocol = "Tcp"
                source_port_range = "*"
                destination_port_range = "3389"
                source_address_prefix = "*"
                destination_address_prefix = "*"
        }
	security_rule{
                name = "default"
                priority = 1003
                direction = "Inbound"
                access = "Allow"
                protocol = "Tcp"
                source_port_range = "*"
                destination_port_range = "80"
                source_address_prefix = "*"
                destination_address_prefix = "*"
        }
}

resource "azurerm_public_ip" "main" {
	name = "public_ip_vm"
	location = azurerm_resource_group.main.location
	resource_group_name = azurerm_resource_group.main.name
	allocation_method = "Dynamic"
}


resource "azurerm_network_interface" "main" {
  name                = "nic-vm-demo"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-demo"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  admin_password = var.admin_password
}

output "public_ip_address" {
  value = azurerm_public_ip.main.ip_address
}

