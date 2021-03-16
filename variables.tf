variable "location" {
  type = string
}

variable "k8s_master_node_count" {
  type = number
}

variable "k8s_worker_node_count" {
  type = number
}

variable "domain" {
  type = string
}

variable "connectivity_resource_group_name" {
  type = string
}