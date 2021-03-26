provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

locals {
  landing_zone_name              = "sandbox"
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

module "common" {
  source  = "app.terraform.io/cloudruler/common/cloudruler"
  version = "1.0.0"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.landing_zone_name}"
  location = var.location
}