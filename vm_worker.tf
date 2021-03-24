resource "azurerm_public_ip" "pip_k8s_worker" {
  count               = local.number_of_k8s_worker_nodes
  name                = "pip-k8s-worker-${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"
  allocation_method   = "Dynamic"
  domain_name_label   = "cloudruler-k8s-worker-${count.index}"
}

resource "azurerm_network_interface" "nic_k8s_worker" {
  count                = local.number_of_k8s_worker_nodes
  name                 = "nic-k8s-worker-${count.index}"
  location             = var.location
  resource_group_name  = azurerm_resource_group.rg.name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "internal-${count.index}"
    subnet_id                     = azurerm_subnet.snet_main.id
    public_ip_address_id          = azurerm_public_ip.pip_k8s_worker[count.index].id
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
  tags = {
    "pod-cidr" = "10.200.${count.index}.0/24"
  }
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

# resource "azurerm_network_interface_application_security_group_association" "asg_k8s_workers_nic_k8s_worker" {
#   count                         = local.number_of_k8s_worker_nodes
#   network_interface_id          = azurerm_network_interface.nic_k8s_worker[count.index].id
#   application_security_group_id = azurerm_application_security_group.asg_k8s_workers.id
# }
