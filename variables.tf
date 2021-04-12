variable "location" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "connectivity_resource_group_name" {
  type = string
}

variable "identity_resource_group_name" {
  type = string
}

variable "key_vault_name" {
  type = string
}

variable "certificate_names" {
  type = set(string)
}

variable "ssh_public_key" {
  type = string
}

variable "cluster_public_ip" {
  type = string
}

variable "master_nodes_config" {
  type = list(object({
    number_of_pods = number
  }))
}

variable "worker_nodes_config" {
  type = list(object({
    number_of_pods = number
  }))
}

variable "vnet_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "bootstrap_token_secret_name" {
  type = string
}

variable "discovery_token_ca_cert_hash_secret_name" {
  type = string
}

variable "api_server_name" {
  type = string
}

variable "k8s_service_subnet" {
  type = string
}

variable "cluster_dns" {
  type = string
}