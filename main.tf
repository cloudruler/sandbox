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

resource "azurerm_application_security_group" "asg_k8s_masters" {
  name                = "asg-k8s-masters"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_application_security_group" "asg_k8s_workers" {
  name                = "asg-k8s-workers"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "nsg_main" {
  name                = "nsg-main"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  #Allow SSH inbound
  security_rule {
    name                       = "nsg-allow-ssh-snet-${local.landing_zone_name}"
    description                = "Allow Inbound SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  #k8s master/worker node rules
  security_rule {
    name                                       = "allow-in-kubelet-api"
    description                                = "Allow Inbound to kubelet API (used by self, control plane)"
    priority                                   = 1002
    direction                                  = "Inbound"
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    source_port_range                          = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id, azurerm_application_security_group.asg_k8s_workers.id]
    destination_port_range                     = "10250"
    access                                     = "Allow"
  }

  security_rule {
    name                                       = "allow-in-kube-scheduler"
    description                                = "Allow Inbound to kube-scheduler (used by self)"
    priority                                   = 1003
    direction                                  = "Inbound"
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    source_port_range                          = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range                     = "10251"
    access                                     = "Allow"
  }

  #k8s master
  security_rule {
    name                                       = "allow-in-k8s-api"
    description                                = "Allow Inbound to Kubernetes API server"
    priority                                   = 1004
    direction                                  = "Inbound"
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    source_port_range                          = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range                     = "6443"
    access                                     = "Allow"
  }

  security_rule {
    name                                       = "allow-in-etcd-clientapi"
    description                                = "Allow Inbound to etcd server client API (used by kube-apiserver, etcd)"
    priority                                   = 1005
    direction                                  = "Inbound"
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    source_port_range                          = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range                     = "2379-2380"
    access                                     = "Allow"
  }

  security_rule {
    name                                       = "allow-in-kube-controller-manager"
    description                                = "Allow Inbound to kube-controller-manager (used by self)"
    priority                                   = 1006
    direction                                  = "Inbound"
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    source_port_range                          = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range                     = "10252"
    access                                     = "Allow"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_snet_main" {
  subnet_id                 = azurerm_subnet.snet_main.id
  network_security_group_id = azurerm_network_security_group.nsg_main.id
}

locals {
  admin_username = "cloudruleradmin"
}

data "azurerm_public_ip" "pip_k8s" {
  name                = "pip-k8s"
  resource_group_name = var.connectivity_resource_group_name
}

locals {
  frontend_ip_configuration_name = "ipconfig-lbe-k8s"
}

resource "azurerm_lb" "lbe_k8s" {
  name                = "lbe-k8s"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = data.azurerm_public_ip.pip_k8s.id
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

resource "azurerm_lb_rule" "lbe_rule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lbe_k8s.id
  name                           = "lbe-k8s-rule"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = local.frontend_ip_configuration_name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lbe_bep_k8s.id
  probe_id                       = azurerm_lb_probe.lbe_prb_k8s.id
}

data "azurerm_ssh_public_key" "ssh_public_key" {
  resource_group_name = "rg-identity"
  name                = "ssh-cloudruler"
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss_k8s_master" {
  name                 = "vmss-k8s-master"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = var.location
  sku                  = "Standard_B2s"
  instances            = var.k8s_master_node_count
  admin_username       = local.admin_username
  computer_name_prefix = "vm-k8s-master"
  custom_data = filebase64("./user-data-master-azure.yml")
  upgrade_mode                = "Automatic"
  health_probe_id             = azurerm_lb_probe.lbe_prb_k8s.id
  platform_fault_domain_count = 5
  depends_on = [

  ]

  automatic_os_upgrade_policy {
    disable_automatic_rollback  = false
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
    #network_security_group_id = "value"
    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.snet_main.id
      application_security_group_ids         = [azurerm_application_security_group.asg_k8s_masters.id]
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbe_bep_k8s.id]
      public_ip_address {
        name              = "pip-k8s"
        domain_name_label = "k8s-master"
        # ip_tag {
        #   tag = "value"
        #   type = "value"
        # }
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {

  }
}
