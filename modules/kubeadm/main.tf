provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

locals {
  route_table_name = "route-k8s-pod"
}
