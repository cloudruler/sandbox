variable "connectivity_resource_group_name" {
  type = string
}

variable "identity_resource_group_name" {
  type = string
}


variable "location" {
  type = string
}

variable "master_nodes_config" {
  type = list(object({
    private_ip_address = string
    number_of_pods     = number
    pod_cidr           = string
  }))
}

variable "worker_nodes_config" {
  type = list(object({
    private_ip_address = string
    number_of_pods     = number
    pod_cidr           = string
  }))
}

variable "vnet_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = string
}
