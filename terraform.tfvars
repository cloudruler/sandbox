#Azure Region to deploy to
location = "southcentralus"
#Resource group for DNS, Public IPs, etc.
connectivity_resource_group_name = "rg-connectivity"
#CIDR for the landing zone
vnet_cidr = "10.1.0.0/16"
#CIDR for the k8s subnet
subnet_cidr = "10.1.0.0/20"
#CIDR for the pods
pods_cidr = "10.96.0.0/12" #"192.168.0.0/16"
#Configuration for the k8s master nodes
master_nodes_config = [ {} ]
#Configuration for the k8s worker nodes
worker_nodes_config = [ {} ]
#Resource group for identities, keys, secrets, and certificates
identity_resource_group_name = "rg-identity"
#Name of the SSH Public Key resource
ssh_public_key = "ssh-cloudruler"
#Name of the public IP to assign to the cluster
cluster_public_ip = "pip-k8s"
#Name of the Key Vault which stores certificates, the discovery CA hash, and the bootstrap token
key_vault_name = "cloudruler"
#A list of Key Vault certificates to inject into the VM
certificate_names = ["ca-kubernetes", "ca-kubernetes-front-proxy", "ca-etcd", "ca-certificate-manager"]
#Name of the bootstrap token secret in Key Vault
bootstrap_token_secret_name = "k8s-bootstrap-token"
#CA hash passed to kubeadm join
discovery_token_ca_cert_hash_secret_name = "k8s-discovery-token-ca-cert-hash"
#The name to reach the api server like k8s.cloudruler.io
api_server_name = "k8s.cloudruler.com"
#Username of the admin user
admin_username = "cloudruleradmin"
#CIDR for k8s services
k8s_service_subnet = "10.96.0.0/12"
cluster_dns        = ""
crio_version = "1.23"
crio_os_version = "xUbuntu_20.04"
vm_image_publisher = {
  publisher = "canonical"
  offer     = "0001-com-ubuntu-server-focal"
  sku       = "20_04-lts-gen2"
  version   = "latest"
}