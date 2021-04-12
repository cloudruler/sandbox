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
    private_ip_address_allocation = "Dynamic"
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
      private_ip_address_allocation = "Dynamic"
      primary                       = false
    }
  }
}

locals {
  worker_custom_data = base64gzip(templatefile(var.master_custom_data_template, {
    node_type      = "worker"
    admin_username = var.admin_username
    vnet_cidr      = var.vnet_cidr
    #subnet_cidr                  = var.subnet_cidr
    certificates               = { for cert_name in var.certificate_names : cert_name => data.azurerm_key_vault_certificate.kv_certificate[cert_name].thumbprint }
    scripts_install_cni_plugin = base64gzip(file("modules/kubeadm/resources/scripts/install-cni-plugin.sh"))
    configs_containerd         = base64gzip(file("modules/kubeadm/resources/configs/containerd-config.toml"))
    configs_kubeadm = base64gzip(templatefile("modules/kubeadm/resources/configs/kubeadm-config.yaml", {
      node_type                    = "worker"
      bootstrap_token              = data.azurerm_key_vault_secret.kv_sc_bootstrap_token.value
      api_server_name              = var.api_server_name
      discovery_token_ca_cert_hash = data.azurerm_key_vault_secret.kv_sc_discovery_token_ca_cert_hash.value
      subnet_cidr                  = var.subnet_cidr
      k8s_service_subnet           = var.k8s_service_subnet
      cluster_dns                  = var.cluster_dns
    }))
    configs_azure = base64gzip(templatefile("modules/kubeadm/resources/configs/azure.json", {
      tenant_id                = data.azurerm_client_config.current.tenant_id
      subscription_id          = data.azurerm_client_config.current.subscription_id
      resource_group_name      = var.resource_group_name
      location                 = var.location
      vnet_resource_group_name = var.resource_group_name
      vnet_name                = azurerm_virtual_network.vnet_zone.name
      subnet_name              = azurerm_subnet.snet_main.name
      nsg_name                 = azurerm_network_security_group.nsg_main.name
      route_table_name         = local.route_table_name
    }))
    manifests_kube_addon_manager    = base64gzip(file("modules/kubeadm/resources/manifests/kube-addon-manager.yaml"))
    addons_audit_policy             = base64gzip(file("modules/kubeadm/resources/addons/audit-policy.yaml"))
    addons_azure_cloud_provider     = base64gzip(file("modules/kubeadm/resources/addons/azure-cloud-provider.yaml"))
    addons_azure_cni_networkmonitor = base64gzip(file("modules/kubeadm/resources/addons/azure-cni-networkmonitor.yaml"))
    addons_blobfuse_flexvolume      = base64gzip(file("modules/kubeadm/resources/addons/blobfuse-flexvolume.yaml"))
    addons_coredns = base64gzip(templatefile("modules/kubeadm/resources/addons/coredns.yaml", {
      cluster_dns = var.cluster_dns
    }))
    addons_secrets_store_csi_driver = base64gzip(file("modules/kubeadm/resources/addons/secrets-store-csi-driver.yaml"))
    addons_ip_masq_agent = base64gzip(templatefile("modules/kubeadm/resources/addons/ip-masq-agent.yaml", {
      vnet_cidr = var.vnet_cidr
    }))
    addons_kube_proxy          = base64gzip(file("modules/kubeadm/resources/addons/kube-proxy.yaml"))
    addons_metrics_server      = base64gzip(file("modules/kubeadm/resources/addons/metrics-server.yaml"))
    addons_pod_security_policy = base64gzip(file("modules/kubeadm/resources/addons/pod-security-policy.yaml"))
  }))
}

resource "azurerm_linux_virtual_machine" "vm_k8s_worker" {
  count               = length(var.worker_nodes_config)
  name                = "vm-k8s-worker-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B2s"
  custom_data         = local.worker_custom_data
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic_k8s_worker[count.index].id,
  ]
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
    sku       = "18.04-LTS" #Eventually upgrade to 19.04 or 19_20-daily-gen2
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  secret {
    key_vault_id = data.azurerm_key_vault.kv.id
    dynamic "certificate" {
      for_each = var.certificate_names
      iterator = certificate_name
      content {
        url = data.azurerm_key_vault_certificate.kv_certificate[certificate_name.value].secret_id
      }
    }
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
