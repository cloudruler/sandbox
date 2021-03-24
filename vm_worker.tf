
resource "azurerm_network_interface" "nic_k8s_worker" {
  count                = local.number_of_k8s_worker_nodes
  name                 = "nic-k8s-worker-${count.index}"
  location             = var.location
  resource_group_name  = azurerm_resource_group.rg.name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "internal-${count.index}"
    subnet_id                     = azurerm_subnet.snet_main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.${local.worker_ip_start + count.index * local.worker_number_of_ips}"
    primary                       = true
  }

  #Disabling these because Kubernetes the Hard Way does not set things up this way
  # dynamic "ip_configuration" {
  #   for_each = range(local.worker_number_of_pods)
  #   iterator = config_index
  #   content {
  #     name                          = "nic-k8s-worker-${count.index}-pod-${config_index.value}"
  #     subnet_id                     = azurerm_subnet.snet_main.id
  #     private_ip_address_allocation = "Static"
  #     private_ip_address            = "10.1.1.${local.worker_ip_start + count.index * local.worker_number_of_ips + config_index.value + 1}"
  #   }
  # }
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

resource "azurerm_application_security_group" "asg_k8s_workers" {
  name                = "asg-k8s-workers"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_lb_backend_address_pool" "lbe_bep_k8s_worker" {
  name            = "lbe-bep-k8s-worker"
  loadbalancer_id = azurerm_lb.lbe_k8s.id
}

resource "azurerm_lb_backend_address_pool_address" "lb_bep_k8s_addr_worker" {
  count                   = local.number_of_k8s_worker_nodes
  name                    = "lb-bep-k8s-addr-worker-${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbe_bep_k8s_worker.id
  virtual_network_id      = azurerm_virtual_network.vnet_zone.id
  ip_address              = azurerm_network_interface.nic_k8s_worker[count.index].private_ip_address
}

resource "azurerm_lb_nat_rule" "lb_nat_k8s_worker" {
  count                          = local.number_of_k8s_worker_nodes
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lbe_k8s.id
  name                           = "nat-ssh-worker-${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = local.number_of_k8s_worker_nodes + count.index + 1
  backend_port                   = 22
  frontend_ip_configuration_name = local.frontend_ip_configuration_name
}

resource "azurerm_network_interface_nat_rule_association" "nic_k8s_worker_lb_nat_k8s_worker" {
  count                 = local.number_of_k8s_worker_nodes
  network_interface_id  = azurerm_network_interface.nic_k8s_worker[count.index].id
  ip_configuration_name = "internal-${count.index}"
  nat_rule_id           = azurerm_lb_nat_rule.lb_nat_k8s_worker[count.index].id
}

resource "azurerm_lb_rule" "lbe_worker_rule" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lbe_k8s.id
  name                           = "lbe-worker-rule"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = local.frontend_ip_configuration_name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lbe_bep_k8s_worker.id
  probe_id                       = azurerm_lb_probe.lbe_prb_k8s.id
}
# resource "azurerm_network_interface_application_security_group_association" "asg_k8s_workers_nic_k8s_worker" {
#   count                         = local.number_of_k8s_worker_nodes
#   network_interface_id          = azurerm_network_interface.nic_k8s_worker[count.index].id
#   application_security_group_id = azurerm_application_security_group.asg_k8s_workers.id
# }
