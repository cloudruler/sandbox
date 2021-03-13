provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

locals {
  zone_name = "sandbox"
}

module "common" {
  source  = "app.terraform.io/cloudruler/common/cloudruler"
  version = "1.0.0"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.zone_name}"
  location = var.location
}

resource "azurerm_virtual_network" "vnet_zone" {
  name                = "vnet-${local.zone_name}"
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "snet_main" {
  name                 = "snet-${local.zone_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet_zone.name
  address_prefixes     = ["10.1.1.0/24"]
}

# # Create public IP
# resource "azurerm_public_ip" "publicip" {
#   name                = "myTFPublicIP"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.rg.name
#   allocation_method   = "Static"
# }

resource "azurerm_network_security_group" "nsg_ssh" {
  name                = "nsg-ssh"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_ssh_snet_main" {
  subnet_id                 = azurerm_subnet.snet_main.id
  network_security_group_id = azurerm_network_security_group.nsg_ssh.id
}

locals {
  admin_username = "cloudruleradmin"
}

resource "azurerm_network_interface" "nic_k8s_master" {
  count               = var.k8s_master_node_count
  name                = "nic-k8s-master-${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_main.id
    private_ip_address_allocation = "dynamic"
    #public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

data "azurerm_ssh_public_key" "ssh_public_key" {
  resource_group_name = "rg-identity"
  name                = "ssh-cloudruler"
}

resource "azurerm_linux_virtual_machine" "vm_k8s_master" {
  count                 = var.k8s_master_node_count
  name                  = "vm-k8s-master-${count.index}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic_k8s_master[count.index].id]
  size                  = "Standard_D2as_v4"
  admin_username        = local.admin_username

  admin_ssh_key {
    username   = local.admin_username
    public_key = data.azurerm_ssh_public_key.ssh_public_key.public_key
  }

  os_disk {
    name                 = "osdisk-k8s-master-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {

  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "vm_k8s_master_shutdown" {
  count                 = var.k8s_master_node_count
  virtual_machine_id    = azurerm_linux_virtual_machine.vm_k8s_master[count.index].id
  location              = azurerm_linux_virtual_machine.vm_k8s_master[count.index].location
  daily_recurrence_time = "0000"
  timezone              = "Central Standard Time"

  notification_settings {
    enabled         = true
    time_in_minutes = "60"
    webhook_url     = "https://sample-webhook-url.example.com"
  }
}

/*
resource "azurerm_linux_virtual_machine_scale_set" "example" {
  name                = "example-vmss"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard_F2"
  instances           = 1
  admin_username      = "adminuser"

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "example"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.internal.id
    }
  }
}
*/
