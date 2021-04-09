provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

module "common" {
  source = "../terraform-cloudruler-common"
  #source  = "app.terraform.io/cloudruler/common/cloudruler"
  #version = "1.0.0"
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
  source                                   = "./modules/kubeadm"
  landing_zone_name                        = local.landing_zone_name
  master_custom_data_template              = "modules/kubeadm/resources/cloud-config.yml"
  worker_custom_data_template              = "modules/kubeadm/resources/cloud-config.yml"
  resource_group_name                      = azurerm_resource_group.rg.name
  location                                 = var.location
  admin_username                           = var.admin_username
  connectivity_resource_group_name         = var.connectivity_resource_group_name
  identity_resource_group_name             = var.identity_resource_group_name
  key_vault_name                           = var.key_vault_name
  certificate_names                        = var.certificate_names
  ssh_public_key                           = var.ssh_public_key
  cluster_public_ip                        = var.cluster_public_ip
  master_nodes_config                      = var.master_nodes_config
  worker_nodes_config                      = var.worker_nodes_config
  vnet_cidr                                = var.vnet_cidr
  subnet_cidr                              = var.subnet_cidr
  bootstrap_token_secret_name              = var.bootstrap_token_secret_name
  discovery_token_ca_cert_hash_secret_name = var.discovery_token_ca_cert_hash_secret_name
  api_server_name                          = var.api_server_name
  k8s_service_subnet                       = var.k8s_service_subnet
  cluster_dns                              = var.cluster_dns
}