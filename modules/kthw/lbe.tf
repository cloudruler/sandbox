
resource "azurerm_lb" "lbe_k8s" {
  name                = "lbe-k8s"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "ipconfig-lbe-k8s"
    public_ip_address_id = data.azurerm_public_ip.pip_k8s.id
  }
}

resource "azurerm_lb_probe" "lbe_prb_k8s" {
  name                = "lbe-prb-k8s-api"
  resource_group_name = var.resource_group_name
  loadbalancer_id     = azurerm_lb.lbe_k8s.id
  protocol            = "Https"
  port                = 6443
  request_path        = "/healthz"
}





