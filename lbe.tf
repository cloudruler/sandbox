
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
  #     #load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lbe_bep_k8s_master.id]
  #     private_ip_address_allocation = "Static"
  #     private_ip_address            = "10.1.1.${local.master_ip_start + count.index * local.master_number_of_ips + config_index.value + 1}"
  #   }
  # }
}

resource "azurerm_lb_probe" "lbe_prb_k8s" {
  name                = "lbe-prb-k8s-api"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lbe_k8s.id
  protocol            = "Https"
  port                = 6443
  request_path        = "/healthz"
}





