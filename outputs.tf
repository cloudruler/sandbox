output "master_custom_data" {
  value = module.aks_cluster.master_custom_data
  sensitive = true
}

output "worker_custom_data" {
  value = module.aks_cluster.worker_custom_data
  sensitive = true
}