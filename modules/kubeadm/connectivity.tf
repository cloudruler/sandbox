resource "azurerm_virtual_network" "vnet_zone" {
  name                = "vnet-${var.landing_zone_name}"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "snet_main" {
  name                 = "snet-${var.landing_zone_name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_zone.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_network_security_group" "nsg_main" {
  name                = "nsg-${var.landing_zone_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  #Allow SSH inbound
  security_rule {
    name                       = "nsg-allow-ssh"
    description                = "Allow Inbound SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  #Allow ICMP inbound
  security_rule {
    name                       = "nsg-allow-icmp"
    description                = "Allow Inbound ICMP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "VirtualNetwork"
    destination_port_range     = "*"
  }

  #k8s master/worker node rules
  security_rule {
    name                       = "allow-in-kubelet-api"
    description                = "Allow Inbound to kubelet API (used by self, control plane)"
    priority                   = 1003
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    #destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id, azurerm_application_security_group.asg_k8s_workers.id]
    destination_port_range = "10250"
    access                 = "Allow"
  }

  security_rule {
    name                       = "allow-in-kube-scheduler"
    description                = "Allow Inbound to kube-scheduler (used by self)"
    priority                   = 1004
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    #destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id, azurerm_application_security_group.asg_k8s_workers.id]
    destination_port_range = "10251"
    access                 = "Allow"
  }

  #k8s master
  security_rule {
    name                       = "allow-in-k8s-api"
    description                = "Allow Inbound to Kubernetes API server"
    priority                   = 1005
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    #destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range = "6443"
    access                 = "Allow"
  }

  security_rule {
    name                       = "allow-in-etcd-clientapi"
    description                = "Allow Inbound to etcd server client API (used by kube-apiserver, etcd)"
    priority                   = 1006
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    #destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range = "2379-2380"
    access                 = "Allow"
  }

  security_rule {
    name                       = "allow-in-kube-controller-manager"
    description                = "Allow Inbound to kube-controller-manager (used by self)"
    priority                   = 1007
    direction                  = "Inbound"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    #destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range = "10252"
    access                 = "Allow"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_snet_main" {
  subnet_id                 = azurerm_subnet.snet_main.id
  network_security_group_id = azurerm_network_security_group.nsg_main.id
}

data "azurerm_public_ip" "pip_k8s" {
  name                = var.cluster_public_ip
  resource_group_name = var.connectivity_resource_group_name
}

data "azurerm_ssh_public_key" "ssh_public_key" {
  resource_group_name = var.identity_resource_group_name
  name                = var.ssh_public_key
}

# resource "azurerm_route_table" "route_k8s_pod" {
#   name                          = local.route_table_name
#   location                      = var.location
#   resource_group_name           = var.resource_group_name
#   disable_bgp_route_propagation = true

#   dynamic "route" {
#     for_each = range(length(var.worker_nodes_config))
#     iterator = worker_node_index
#     content {
#       name                   = "udr-k8s-pod-${worker_node_index.value}"
#       address_prefix         = var.worker_nodes_config[worker_node_index.value].pod_cidr
#       next_hop_type          = "VirtualAppliance"
#       next_hop_in_ip_address = azurerm_linux_virtual_machine.vm_k8s_worker[worker_node_index.value].private_ip_address
#     }
#   }
# }

# resource "azurerm_subnet_route_table_association" "snet_main_route_k8s_pod" {
#   subnet_id      = azurerm_subnet.snet_main.id
#   route_table_id = azurerm_route_table.route_k8s_pod.id
# }

resource "azurerm_private_dns_zone" "dns" {
  name                = "cloudruler.com"
  resource_group_name = var.connectivity_resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet" {
  name                  = "dns-vnet-${var.landing_zone_name}"
  resource_group_name   = var.connectivity_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.dns.name
  virtual_network_id    = azurerm_virtual_network.vnet_zone.id
  registration_enabled  = true
}

resource "azurerm_private_dns_a_record" "k8s_endpoint" {
  #count               = length(var.master_nodes_config)
  name                = "k8s"
  zone_name           = azurerm_private_dns_zone.dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_linux_virtual_machine.vm_k8s_master[0].private_ip_address]
}