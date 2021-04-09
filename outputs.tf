output "master_custom_data" {
  value = module.kubeadm.master_custom_data
}

output "worker_custom_data" {
  value = module.kubeadm.worker_custom_data
}