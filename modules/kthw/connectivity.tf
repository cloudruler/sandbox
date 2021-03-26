resource "azurerm_virtual_network" "vnet_zone" {
  name                = "vnet-${local.landing_zone_name}"
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "snet_main" {
  name                 = "snet-${local.landing_zone_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet_zone.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_security_group" "nsg_main" {
  name                = "nsg-main"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  #Allow SSH inbound
  security_rule {
    name                       = "nsg-allow-ssh-snet-${local.landing_zone_name}"
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
    name                       = "nsg-allow-icmp-snet-${local.landing_zone_name}"
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
    name                                       = "allow-in-kubelet-api"
    description                                = "Allow Inbound to kubelet API (used by self, control plane)"
    priority                                   = 1003
    direction                                  = "Inbound"
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    source_port_range                          = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id, azurerm_application_security_group.asg_k8s_workers.id]
    destination_port_range                     = "10250"
    access                                     = "Allow"
  }

  security_rule {
    name                                       = "allow-in-kube-scheduler"
    description                                = "Allow Inbound to kube-scheduler (used by self)"
    priority                                   = 1004
    direction                                  = "Inbound"
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    source_port_range                          = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range                     = "10251"
    access                                     = "Allow"
  }

  #k8s master
  security_rule {
    name                                       = "allow-in-k8s-api"
    description                                = "Allow Inbound to Kubernetes API server"
    priority                                   = 1005
    direction                                  = "Inbound"
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    source_port_range                          = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range                     = "6443"
    access                                     = "Allow"
  }

  security_rule {
    name                                       = "allow-in-etcd-clientapi"
    description                                = "Allow Inbound to etcd server client API (used by kube-apiserver, etcd)"
    priority                                   = 1006
    direction                                  = "Inbound"
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    source_port_range                          = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range                     = "2379-2380"
    access                                     = "Allow"
  }

  security_rule {
    name                                       = "allow-in-kube-controller-manager"
    description                                = "Allow Inbound to kube-controller-manager (used by self)"
    priority                                   = 1007
    direction                                  = "Inbound"
    protocol                                   = "Tcp"
    source_address_prefix                      = "*"
    source_port_range                          = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.asg_k8s_masters.id]
    destination_port_range                     = "10252"
    access                                     = "Allow"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_snet_main" {
  subnet_id                 = azurerm_subnet.snet_main.id
  network_security_group_id = azurerm_network_security_group.nsg_main.id
}

#10.1.1.0/24
#10.1.1.4 to 10.1.1.254
#Master node 1: 10.1.1.4 to 10.1.1.34
#Master node 2: 10.1.1.35 to 10.1.1.65
#Master node 3: 10.1.1.66 to 10.1.1.96
#Worker node 1: 10.1.1.97 to 10.1.1.127
#Worker node 2: 10.1.1.128 to 10.1.1.158
#Worker node 3: 10.1.1.159 to 10.1.1.189
data "azurerm_public_ip" "pip_k8s" {
  name                = "pip-k8s"
  resource_group_name = var.connectivity_resource_group_name
}

data "azurerm_ssh_public_key" "ssh_public_key" {
  resource_group_name = "rg-identity"
  name                = "ssh-cloudruler"
}

resource "azurerm_route_table" "route_k8s_pod" {
  name                          = "route-k8s-pod"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = true

  dynamic "route" {
    for_each = range(local.number_of_k8s_worker_nodes)
    iterator = worker_node_index
    content {
      name                   = "udr-k8s-pod-${worker_node_index.value}"
      address_prefix         = "10.200.${worker_node_index.value}.0/24"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = azurerm_linux_virtual_machine.vm_k8s_worker[worker_node_index.value].private_ip_address
    }
  }
}

resource "azurerm_subnet_route_table_association" "snet_main_route_k8s_pod" {
  subnet_id      = azurerm_subnet.snet_main.id
  route_table_id = azurerm_route_table.route_k8s_pod.id
}

