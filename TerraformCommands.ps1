0,1,2 | ForEach-Object { terraform taint "azurerm_linux_virtual_machine.vm_k8s_master[$_]"; terraform taint "azurerm_linux_virtual_machine.vm_k8s_worker[$_]"; }


terraform import module.kubeadm.azurerm_network_interface_application_security_group_association.asg_k8s_masters_nic_k8s_master "/subscriptions/2fb80bcc-8430-4b66-868b-8253e48a8317/resourceGroups/rg-sandbox/providers/Microsoft.Network/networkInterfaces/nic-k8s-master-0|/subscriptions/2fb80bcc-8430-4b66-868b-8253e48a8317/resourceGroups/rg-sandbox/providers/Microsoft.Network/applicationSecurityGroups/asg-k8s-masters"


terraform state rm azurerm_application_security_group.asg_k8s_masters        
terraform state rm azurerm_application_security_group.asg_k8s_workers        
terraform state rm azurerm_lb.lbe_k8s
terraform state rm azurerm_lb_backend_address_pool.lbe_bep_k8s
terraform state rm azurerm_lb_backend_address_pool_address.lb_bep_k8s_addr[0]
terraform state rm azurerm_lb_backend_address_pool_address.lb_bep_k8s_addr[1]
terraform state rm azurerm_lb_backend_address_pool_address.lb_bep_k8s_addr[2]
terraform state rm azurerm_lb_nat_rule.lb_nat_k8s_master[0]
terraform state rm azurerm_lb_nat_rule.lb_nat_k8s_master[1]
terraform state rm azurerm_lb_nat_rule.lb_nat_k8s_master[2]
terraform state rm azurerm_lb_nat_rule.lb_nat_k8s_worker[0]
terraform state rm azurerm_lb_nat_rule.lb_nat_k8s_worker[1]
terraform state rm azurerm_lb_nat_rule.lb_nat_k8s_worker[2]
terraform state rm azurerm_network_interface.nic_k8s_master[0]
terraform state rm azurerm_network_interface.nic_k8s_master[1]
terraform state rm azurerm_network_interface.nic_k8s_master[2]
terraform state rm azurerm_network_interface.nic_k8s_worker[0]
terraform state rm azurerm_network_interface.nic_k8s_worker[1]
terraform state rm azurerm_network_interface.nic_k8s_worker[2]
terraform state rm azurerm_network_interface_application_security_group_association.asg_k8s_masters_nic_k8s_master[0]
terraform state rm azurerm_network_interface_application_security_group_association.asg_k8s_masters_nic_k8s_master[1]
terraform state rm azurerm_network_interface_application_security_group_association.asg_k8s_masters_nic_k8s_master[2]
terraform state rm azurerm_network_interface_application_security_group_association.asg_k8s_workers_nic_k8s_worker[2]
terraform state rm azurerm_network_interface_nat_rule_association.nic_k8s_master_lb_nat_k8s_master[0]
terraform state rm azurerm_network_interface_nat_rule_association.nic_k8s_master_lb_nat_k8s_master[1]
terraform state rm azurerm_network_interface_nat_rule_association.nic_k8s_master_lb_nat_k8s_master[2]
terraform state rm azurerm_network_interface_nat_rule_association.nic_k8s_worker_lb_nat_k8s_worker[0]
terraform state rm azurerm_network_interface_nat_rule_association.nic_k8s_worker_lb_nat_k8s_worker[1]
terraform state rm azurerm_network_security_group.nsg_main
terraform state rm azurerm_resource_group.rg
terraform state rm azurerm_subnet.snet_main
terraform state rm azurerm_virtual_network.vnet_zone