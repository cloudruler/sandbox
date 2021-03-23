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

  #Allow ICMP inbound
  security_rule {
    name                       = "nsg-allow-icmp-snet-${local.landing_zone_name}"
    description                = "Allow Inbound ICMP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_range     = "*"
  }

  #k8s master/worker node rules
  security_rule {
    name                       = "allow-in-kubelet-api"
    description                = "Allow Inbound to kubelet API (used by self, control plane)"
    priority                   = 1003
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    #destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id, azurerm_application_security_group.asg_k8s_workers.id]
    destination_port_range = "10250"
    access                 = "Allow"
  }

  security_rule {
    name                       = "allow-in-kube-scheduler"
    description                = "Allow Inbound to kube-scheduler (used by self)"
    priority                   = 1004
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    #destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range = "10251"
    access                 = "Allow"
  }

  #k8s master
  security_rule {
    name                       = "allow-in-k8s-api"
    description                = "Allow Inbound to Kubernetes API server"
    priority                   = 1005
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    #destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range = "6443"
    access                 = "Allow"
  }

  security_rule {
    name                       = "allow-in-etcd-clientapi"
    description                = "Allow Inbound to etcd server client API (used by kube-apiserver, etcd)"
    priority                   = 1006
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    #destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range = "2379-2380"
    access                 = "Allow"
  }

  security_rule {
    name                       = "allow-in-kube-controller-manager"
    description                = "Allow Inbound to kube-controller-manager (used by self)"
    priority                   = 1007
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    #destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range = "10252"
    access                 = "Allow"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_snet_main" {
  subnet_id                 = azurerm_subnet.snet_main.id
  network_security_group_id = azurerm_network_security_group.nsg_main.id
}

locals {
  admin_username                 = "cloudruleradmin"
  number_of_k8s_master_nodes     = 3
  number_of_k8s_worker_nodes     = 3
  master_number_of_pods          = 30
  worker_number_of_pods          = 30
  master_number_of_ips           = local.master_number_of_pods + 1
  worker_number_of_ips           = local.worker_number_of_pods + 1
  master_ip_start                = 4 #Skip 0-3 which are reserved
  worker_ip_start                = local.master_ip_start + local.number_of_k8s_master_nodes * (local.worker_number_of_pods + 1)
  frontend_ip_configuration_name = "ipconfig-lbe-k8s"
}
#10.1.1.0/24
#10.1.1.4 to 10.1.1.254
#Master node 1: 10.1.1.4 to 10.1.1.34
#Master node 2: 10.1.1.35 to 10.1.1.65
#Master node 3: 10.1.1.66 to 10.1.1.96
#Worker node 1: 10.1.1.97 to 10.1.1.127
#Worker node 2: 10.1.1.128 to 10.1.1.158
#Worker node 3: 10.1.1.159 to 10.1.1.189
data "azurerm_public_ip" "pip_k8s" {
  name                = "pip-k8s"
  resource_group_name = var.connectivity_resource_group_name
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

  # dynamic "frontend_ip_configuration" {
  #   for_each = range(local.number_of_k8s_master_nodes)
  #   iterator = config_index
  #   content {
  #     name      = "ipconfig-nat-k8s-master-${count.index}"
  #     subnet_id = azurerm_subnet.snet_main.id
  #     #application_security_group_ids         = [azurerm_application_security_group.asg_k8s_masters.id]
  #     #load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbe_bep_k8s.id]
  #     private_ip_address_allocation = "Static"
  #     private_ip_address            = "10.1.1.${local.master_ip_start + count.index * local.master_number_of_ips + config_index.value + 1}"
  #   }
  # }
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

resource "azurerm_network_interface" "nic_k8s_master" {
  count               = local.number_of_k8s_master_nodes
  name                = "nic-k8s-master-${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal-${count.index}"
    subnet_id                     = azurerm_subnet.snet_main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.${local.master_ip_start + count.index * local.master_number_of_ips}"
    primary                       = true
  }

  #No point in allocating pod CIDR for master nodes
  # dynamic "ip_configuration" {
  #   for_each = range(local.master_number_of_pods)
  #   iterator = config_index
  #   content {
  #     name      = "nic-k8s-master-${count.index}-pod-${config_index.value}"
  #     subnet_id = azurerm_subnet.snet_main.id
  #     #application_security_group_ids         = [azurerm_application_security_group.asg_k8s_masters.id]
  #     #load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbe_bep_k8s.id]
  #     private_ip_address_allocation = "Static"
  #     private_ip_address            = "10.1.1.${local.master_ip_start + count.index * local.master_number_of_ips + config_index.value + 1}"
  #   }
  # }
}

resource "azurerm_linux_virtual_machine" "vm_k8s_master" {
  count               = local.number_of_k8s_master_nodes
  name                = "vm-k8s-master-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_B2s"
  #custom_data                 = filebase64("./user-data-master-azure.yml")
  admin_username = local.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic_k8s_master[count.index].id,
  ]

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
}

# resource "azurerm_network_interface_application_security_group_association" "asg_k8s_masters_nic_k8s_master" {
#   count                         = local.number_of_k8s_master_nodes
#   network_interface_id          = azurerm_network_interface.nic_k8s_master[count.index].id
#   application_security_group_id = azurerm_application_security_group.asg_k8s_masters.id
# }

resource "azurerm_lb_backend_address_pool_address" "lb_bep_k8s_addr" {
  count                   = local.number_of_k8s_master_nodes
  name                    = "lb-bep-k8s-addr-${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbe_bep_k8s.id
  virtual_network_id      = azurerm_virtual_network.vnet_zone.id
  ip_address              = "10.1.1.${local.master_ip_start + count.index * local.master_number_of_ips}"
}









resource "azurerm_network_interface" "nic_k8s_worker" {
  count               = local.number_of_k8s_worker_nodes
  name                = "nic-k8s-worker-${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal-${count.index}"
    subnet_id                     = azurerm_subnet.snet_main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.${local.worker_ip_start + count.index * local.worker_number_of_ips}"
    primary                       = true
  }

  dynamic "ip_configuration" {
    for_each = range(local.worker_number_of_pods)
    iterator = config_index
    content {
      name      = "nic-k8s-worker-${count.index}-pod-${config_index.value}"
      subnet_id = azurerm_subnet.snet_main.id
      private_ip_address_allocation = "Static"
      private_ip_address            = "10.1.1.${local.worker_ip_start + count.index * local.worker_number_of_ips + config_index.value + 1}"
    }
  }
}

resource "azurerm_linux_virtual_machine" "vm_k8s_worker" {
  count               = local.number_of_k8s_worker_nodes
  name                = "vm-k8s-worker-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_B2s"
  #custom_data                 = filebase64("./user-data-worker-azure.yml")
  admin_username = local.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic_k8s_worker[count.index].id,
  ]

  admin_ssh_key {
    username   = local.admin_username
    public_key = data.azurerm_ssh_public_key.ssh_public_key.public_key
  }

  os_disk {
    name                 = "osdisk-k8s-worker-${count.index}"
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
}

# resource "azurerm_network_interface_application_security_group_association" "asg_k8s_workers_nic_k8s_worker" {
#   count                         = local.number_of_k8s_worker_nodes
#   network_interface_id          = azurerm_network_interface.nic_k8s_worker[count.index].id
#   application_security_group_id = azurerm_application_security_group.asg_k8s_workers.id
# }

resource "azurerm_lb_nat_rule" "lb_nat_k8s_master" {
  count                          = local.number_of_k8s_master_nodes
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lbe_k8s.id
  name                           = "nat-ssh-master-${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = count.index + 1
  backend_port                   = 22
  frontend_ip_configuration_name = local.frontend_ip_configuration_name
}

# resource "azurerm_network_interface_nat_rule_association" "nic_k8s_master_lb_nat_k8s_master" {
#   count                 = local.number_of_k8s_master_nodes
#   network_interface_id  = azurerm_network_interface.nic_k8s_master[count.index].id
#   ip_configuration_name = "internal-${count.index}"
#   nat_rule_id           = azurerm_lb_nat_rule.lb_nat_k8s_master[count.index].id
# }

resource "azurerm_lb_nat_rule" "lb_nat_k8s_worker" {
  count                          = local.number_of_k8s_worker_nodes
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lbe_k8s.id
  name                           = "nat-ssh-worker-${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = local.number_of_k8s_master_nodes + count.index + 1
  backend_port                   = 22
  frontend_ip_configuration_name = local.frontend_ip_configuration_name
}

resource "azurerm_network_interface_nat_rule_association" "nic_k8s_worker_lb_nat_k8s_worker" {
  count                 = local.number_of_k8s_worker_nodes
  network_interface_id  = azurerm_network_interface.nic_k8s_worker[count.index].id
  ip_configuration_name = "internal-${count.index}"
  nat_rule_id           = azurerm_lb_nat_rule.lb_nat_k8s_worker[count.index].id
}








# resource "azurerm_linux_virtual_machine_scale_set" "vmss_k8s_master" {
#   name                        = "vmss-k8s-master"
#   resource_group_name         = azurerm_resource_group.rg.name
#   location                    = var.location
#   sku                         = "Standard_B2s"
#   instances                   = var.k8s_master_node_count
#   admin_username              = local.admin_username
#   computer_name_prefix        = "vm-k8s-master"
#   custom_data                 = filebase64("./user-data-master-azure.yml")
#   upgrade_mode                = "Automatic"
#   health_probe_id             = azurerm_lb_probe.lbe_prb_k8s.id
#   platform_fault_domain_count = 5
#   tags                        = {}
#   zones                       = []
#   encryption_at_host_enabled  = false
#   depends_on = [

#   ]

#   automatic_os_upgrade_policy {
#     disable_automatic_rollback  = false
#     enable_automatic_os_upgrade = true
#   }

#   rolling_upgrade_policy {
#     max_batch_instance_percent              = 20
#     max_unhealthy_instance_percent          = 20
#     max_unhealthy_upgraded_instance_percent = 20
#     pause_time_between_batches              = "PT0S"
#   }

#   terminate_notification {
#     enabled = false
#   }

#   admin_ssh_key {
#     username   = local.admin_username
#     public_key = data.azurerm_ssh_public_key.ssh_public_key.public_key
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }

#   network_interface {
#     name    = "nic-k8s-master"
#     primary = true
#     #network_security_group_id = "value"
#     ip_configuration {
#       name                                   = "internal"
#       primary                                = true
#       subnet_id                              = azurerm_subnet.snet_main.id
#       application_security_group_ids         = [azurerm_application_security_group.asg_k8s_masters.id]
#       load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbe_bep_k8s.id]
#       #public_ip_address {
#       #name              = "pip-k8s"
#       #domain_name_label = "k8s-master"
#       # ip_tag {
#       #   tag = "value"
#       #   type = "value"
#       # }
#       #}
#     }

#     dynamic "ip_configuration" {
#       for_each = range(30)
#       iterator = config_index
#       content {
#         name      = "pod-${config_index.value}"
#         subnet_id = azurerm_subnet.snet_main.id
#         application_security_group_ids         = [azurerm_application_security_group.asg_k8s_masters.id]
#         load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbe_bep_k8s.id]
#       }
#     }
#   }

#   identity {
#     type = "SystemAssigned"
#   }

#   boot_diagnostics {

#   }
# }
