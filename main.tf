provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

module "common" {
  source  = "app.terraform.io/cloudruler/common/cloudruler"
  version = "1.0.0"
}

locals {
  landing_zone_name = "sandbox"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.landing_zone_name}"
  location = var.location
}

# module "kthw" {
#   source                           = "./modules/kthw"
#   landing_zone_name                = local.landing_zone_name
#   resource_group_name              = azurerm_resource_group.rg.name
#   location                         = var.location
#   admin_username                   = "cloudruleradmin"
#   connectivity_resource_group_name = "rg-connectivity"
#   identity_resource_group_name     = "rg-identity"
#   ssh_public_key                   = "ssh-cloudruler"
#   cluster_public_ip                = "pip-k8s"
#   master_nodes_config              = var.master_nodes_config
#   worker_nodes_config              = var.worker_nodes_config
#   vnet_cidr                        = var.vnet_cidr
#   subnet_cidr                      = var.subnet_cidr
# }

module "kubeadm" {
  source                           = "./modules/kubeadm"
  landing_zone_name                = local.landing_zone_name
  custom_data                      = filebase64("./modules/kubeadm/user-data-master-azure.yml")
  resource_group_name              = azurerm_resource_group.rg.name
  location                         = var.location
  admin_username                   = "cloudruleradmin"
  connectivity_resource_group_name = var.connectivity_resource_group_name
  identity_resource_group_name     = var.identity_resource_group_name
  ssh_public_key                   = var.ssh_public_key
  cluster_public_ip                = var.cluster_public_ip
  master_nodes_config              = var.master_nodes_config
  worker_nodes_config              = var.worker_nodes_config
  vnet_cidr                        = var.vnet_cidr
  subnet_cidr                      = var.subnet_cidr
}