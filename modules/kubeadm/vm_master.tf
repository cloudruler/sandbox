resource "azurerm_public_ip" "pip_k8s_master" {
  count               = length(var.master_nodes_config)
  name                = "pip-k8s-master-${count.index}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "cloudruler-k8s-master-${count.index}"
}

resource "azurerm_network_interface" "nic_k8s_master" {
  count                = length(var.master_nodes_config)
  name                 = "nic-k8s-master-${count.index}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "internal-${count.index}"
    subnet_id                     = azurerm_subnet.snet_main.id
    public_ip_address_id          = azurerm_public_ip.pip_k8s_master[count.index].id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
  }

  dynamic "ip_configuration" {
    for_each = range(var.master_nodes_config[count.index].number_of_pods)
    iterator = config_index
    content {
      name      = "nic-k8s-master-${count.index}-pod-${config_index.value}"
      subnet_id = azurerm_subnet.snet_main.id
      #application_security_group_ids         = [azurerm_application_security_group.asg_k8s_workers.id]
      #load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbe_bep_k8s_worker.id]
      private_ip_address_allocation = "Dynamic"
      primary                       = false
    }
  }
}

locals {
  master_custom_data = base64gzip(templatefile(var.master_custom_data_template, {
    node_type      = "master"
    admin_username = var.admin_username
    vnet_cidr      = var.vnet_cidr
    #subnet_cidr                  = var.subnet_cidr
    certificates               = { for cert_name in var.certificate_names : cert_name => data.azurerm_key_vault_certificate.kv_certificate[cert_name].thumbprint }
    scripts_install_cni_plugin = base64gzip(file("modules/kubeadm/resources/scripts/install-cni-plugin.sh"))
    configs_containerd         = base64gzip(file("modules/kubeadm/resources/configs/containerd-config.toml"))
    configs_kubeadm = base64gzip(templatefile("modules/kubeadm/resources/configs/kubeadm-config.yaml", {
      node_type                    = "master"
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

resource "azurerm_linux_virtual_machine" "vm_k8s_master" {
  count               = length(var.master_nodes_config)
  name                = "vm-k8s-master-${count.index}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B2s"
  custom_data         = local.master_custom_data
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic_k8s_master[count.index].id,
  ]
  admin_ssh_key {
    username   = var.admin_username
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

resource "azurerm_application_security_group" "asg_k8s_masters" {
  name                = "asg-k8s-masters"
  location            = var.location
  resource_group_name = var.resource_group_name
}

# resource "azurerm_network_interface_application_security_group_association" "asg_k8s_masters_nic_k8s_master" {
#   count                         = length(var.master_nodes_config)
#   network_interface_id          = azurerm_network_interface.nic_k8s_master[count.index].id
#   application_security_group_id = azurerm_application_security_group.asg_k8s_masters.id
# }

resource "azurerm_lb_backend_address_pool" "lbe_bep_k8s_master" {
  name            = "lbe-bep-k8s-master"
  loadbalancer_id = azurerm_lb.lbe_k8s.id
}

# resource "azurerm_network_interface_backend_address_pool_association" "lb_bep_k8s_nic_master" {
#   count                   = length(var.master_nodes_config)
#   network_interface_id    = azurerm_network_interface.nic_k8s_master[count.index].id
#   ip_configuration_name   = "internal-${count.index}"
#   backend_address_pool_id = azurerm_lb_backend_address_pool.lbe_bep_k8s_master.id
# }

resource "azurerm_lb_nat_rule" "lb_nat_k8s_master" {
  count                          = length(var.master_nodes_config)
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.lbe_k8s.id
  name                           = "nat-ssh-master-${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = count.index + 1
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.lbe_k8s.frontend_ip_configuration[0].name
}

# resource "azurerm_network_interface_nat_rule_association" "nic_k8s_master_lb_nat_k8s_master" {
#   count                 = length(var.master_nodes_config)
#   network_interface_id  = azurerm_network_interface.nic_k8s_master[count.index].id
#   ip_configuration_name = "internal-${count.index}"
#   nat_rule_id           = azurerm_lb_nat_rule.lb_nat_k8s_master[count.index].id
# }

resource "azurerm_lb_outbound_rule" "lbe_out_rule_k8s_master" {
  resource_group_name     = var.resource_group_name
  loadbalancer_id         = azurerm_lb.lbe_k8s.id
  name                    = "lbe-master-rule"
  protocol                = "Tcp"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbe_bep_k8s_master.id

  frontend_ip_configuration {
    name = azurerm_lb.lbe_k8s.frontend_ip_configuration[0].name
  }
}

resource "azurerm_lb_rule" "lbe_k8s_api_rule" {
  resource_group_name            = var.resource_group_name
  loadbalancer_id                = azurerm_lb.lbe_k8s.id
  name                           = "lbe-k8s-api-rule"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = azurerm_lb.lbe_k8s.frontend_ip_configuration[0].name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lbe_bep_k8s_master.id
  probe_id                       = azurerm_lb_probe.lbe_prb_k8s.id
  disable_outbound_snat          = true
}

# resource "azurerm_linux_virtual_machine_scale_set" "vmss_k8s_master" {
#   name                        = "vmss-k8s-master"
#   resource_group_name         = var.resource_group_name
#   location                    = var.location
#   sku                         = "Standard_B2s"
#   instances                   = var.k8s_master_node_count
#   admin_username              = var.admin_username
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
#     username   = var.admin_username
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
#       load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbe_bep_k8s_master.id]
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
#         load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbe_bep_k8s_master.id]
#       }
#     }
#   }

#   identity {
#     type = "SystemAssigned"
#   }

#   boot_diagnostics {

#   }
# }
