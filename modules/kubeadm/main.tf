provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "kv" {
  name                = var.key_vault_name
  resource_group_name = var.identity_resource_group_name
}

data "azurerm_key_vault_secret" "kv_sc_bootstrap_token" {
  name         = var.bootstrap_token_secret_name
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "kv_sc_discovery_token_ca_cert_hash" {
  name         = var.discovery_token_ca_cert_hash_secret_name
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_certificate" "kv_certificate" {
  for_each     = var.certificate_names
  name         = each.value
  key_vault_id = data.azurerm_key_vault.kv.id
}

locals {
  route_table_name = "route-k8s-pod"
}
