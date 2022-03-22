provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

locals {
  landing_zone_name = "sandbox"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.landing_zone_name}"
  location = var.location
}

module "aks_cluster" {
  source                                   = "../terraform-azurerm-aks_cluster"
  #source                                   = "app.terraform.io/cloudruler/aks_cluster/azurerm"
  #version                                 = ">= 0.0.1"
  landing_zone_name                        = local.landing_zone_name
  master_custom_data_template              = "resources/cloud-config.yaml"
  worker_custom_data_template              = "resources/cloud-config.yaml"
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
  pods_cidr                                = var.pods_cidr
  bootstrap_token_secret_name              = var.bootstrap_token_secret_name
  discovery_token_ca_cert_hash_secret_name = var.discovery_token_ca_cert_hash_secret_name
  api_server_name                          = var.api_server_name
  k8s_service_subnet                       = var.k8s_service_subnet
  cluster_dns                              = var.cluster_dns
  crio_version                             = var.crio_version
  crio_os_version                          = var.crio_os_version
}
