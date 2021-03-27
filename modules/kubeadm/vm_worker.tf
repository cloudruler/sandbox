resource "azurerm_public_ip" "pip_k8s_worker" {
  count               = length(var.worker_nodes_config)
  name                = "pip-k8s-worker-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  allocation_method   = "Dynamic"
  domain_name_label   = "cloudruler-k8s-worker-${count.index}"
}

resource "azurerm_network_interface" "nic_k8s_worker" {
  count                = length(var.worker_nodes_config)
  name                 = "nic-k8s-worker-${count.index}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "internal-${count.index}"
    subnet_id                     = azurerm_subnet.snet_main.id
    public_ip_address_id          = azurerm_public_ip.pip_k8s_worker[count.index].id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.worker_nodes_config[count.index].private_ip_address
    primary                       = true
  }

  dynamic "ip_configuration" {
    for_each = range(var.worker_nodes_config[count.index].number_of_pods)
    iterator = config_index
    content {
      name      = "nic-k8s-worker-${count.index}-pod-${config_index.value}"
      subnet_id = azurerm_subnet.snet_main.id
      #application_security_group_ids         = [azurerm_application_security_group.asg_k8s_workers.id]
      #load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbe_bep_k8s_worker.id]
      private_ip_address_allocation = "Static"
      private_ip_address            = cidrhost(var.worker_nodes_config[count.index].pod_cidr, config_index.value)
    }
  }
}

resource "azurerm_linux_virtual_machine" "vm_k8s_worker" {
  count               = length(var.worker_nodes_config)
  name                = "vm-k8s-worker-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B2s"
  custom_data = base64encode(templatefile(var.worker_custom_data_template, {
    pod_cidr = var.worker_nodes_config[count.index].pod_cidr
    vnet_cidr = var.vnet_cidr
    subnet_cidr = var.subnet_cidr
    tenant_id = var.tenant_id
    subscription_id = var.subscription_id
    resource_group_name = var.resource_group_name
    location = var.location
    subnet_name = azurerm_subnet.snet_main.name
    nsg_name = azurerm_network_security_group.nsg_main.name
    vnet_name = azurerm_virtual_network.vnet_zone.name
    vnet_resource_group = var.resource_group_name
    route_table_name = azurerm_route_table.route_k8s_pod.name
  }))
  admin_username = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic_k8s_worker[count.index].id,
  ]
  tags = {
    "pod-cidr" = var.worker_nodes_config[count.index].pod_cidr
  }
  admin_ssh_key {
    username   = var.admin_username
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
  resource_group_name = var.resource_group_name
}

resource "azurerm_network_interface_application_security_group_association" "asg_k8s_workers_nic_k8s_worker" {
  count                         = length(var.worker_nodes_config)
  network_interface_id          = azurerm_network_interface.nic_k8s_worker[count.index].id
  application_security_group_id = azurerm_application_security_group.asg_k8s_workers.id
}
