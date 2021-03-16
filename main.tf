provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

locals {
  landing_zone_name = "sandbox"
}

module "common" {
  source  = "app.terraform.io/cloudruler/common/cloudruler"
  version = "1.0.0"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.landing_zone_name}"
  location = var.location
}

resource "azurerm_virtual_network" "vnet_zone" {
  name                = "vnet-${local.landing_zone_name}"
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "snet_main" {
  name                 = "snet-${local.landing_zone_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet_zone.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_security_group" "nsg_ssh" {
  name                = "nsg-ssh"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "nsg-allow-ssh-snet-${local.landing_zone_name}"
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

resource "azurerm_public_ip" "pip_k8s" {
  name                = "pip-k8s"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "cloudruler-k8s"
}

data "azurerm_dns_zone" "dns_zone" {
  name                = var.domain
  resource_group_name = "rg-connectivity"
}

resource "azurerm_dns_a_record" "dns_a_k8s" {
  name                = "k8s"
  zone_name           = data.azurerm_dns_zone.dns_zone.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 3600
  target_resource_id  = azurerm_public_ip.pip_k8s.id
}

resource "azurerm_lb" "lbe_k8s" {
  name                = "lbe-k8s"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "ipconfig-lbe-k8s"
    public_ip_address_id = azurerm_public_ip.pip_k8s.id
  }
}

resource "azurerm_lb_backend_address_pool" "lbe_bep_k8s" {
  name            = "lbe-bep-k8s"
  loadbalancer_id = azurerm_lb.lbe_k8s.id
}

resource "azurerm_lb_probe" "lbe_prb_k8s" {
  name                = "lbe-prb-k8s-ssh"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lbe_k8s.id
  port                = 22

}

/*
resource "azurerm_lb_backend_address_pool_address" "lbe_badr_k8s" {
  name                    = "lbe-badr-k8s"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbe_bep_k8s.id
  virtual_network_id      = azurerm_virtual_network.vnet_zone.id
  ip_address              = "10.0.0.1"
}
*/

data "azurerm_ssh_public_key" "ssh_public_key" {
  resource_group_name = "rg-identity"
  name                = "ssh-cloudruler"
}

/*
resource "azurerm_linux_virtual_machine_scale_set" "vmss_k8s_master" {
  name                = "vmss-k8s-master"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Standard_D2as_v4"
  instances           = var.k8s_master_node_count
  admin_username      = local.admin_username
  computer_name_prefix = "vm-k8s-master"
  custom_data = ""
  upgrade_mode = "Automatic"
  health_probe_id = azurerm_lb_probe.lbe_prb_k8s.id
  platform_fault_domain_count = 5
  depends_on = [
    
  ]

  automatic_os_upgrade_policy {
    disable_automatic_rollback = false
    enable_automatic_os_upgrade = true
  }

  admin_ssh_key {
    username   = local.admin_username
    public_key = data.azurerm_ssh_public_key.ssh_public_key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  network_interface {
    name    = "nic-k8s-master"
    primary = true
    network_security_group_id = "value"
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.internal.id
      application_security_group_ids = [ "" ]
      load_balancer_backend_address_pool_ids = [ "" ]
      public_ip_address {
        name = ""
        domain_name_label = "k8s-master-${count.index}"

      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {

  }
}

  domain_name_label   = "k8s-master"
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_main.id
    private_ip_address_allocation = "dynamic"
    #public_ip_address_id          = azurerm_public_ip.pip_k8s.id
  }
*/

