output "frontend_ip_configuration_id" {
  value = azurerm_lb.lbe_k8s.frontend_ip_configuration.id
}