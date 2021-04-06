#Azure Region to deploy to
location = "southcentralus"
#Resource group for DNS, Public IPs, etc.
connectivity_resource_group_name = "rg-connectivity"
#CIDR for the landing zone
vnet_cidr = "10.1.0.0/16"
#CIDR for the k8s subnet
subnet_cidr = "10.1.0.0/20"
#Configuration for the k8s master nodes
master_nodes_config = [
    {
        private_ip_address = "10.1.0.4"
        number_of_pods = 0
        pod_cidr = "10.1.0.0/20"
    },
    #{
    #    private_ip_address = "10.1.0.5"
    #    number_of_pods = 0
    #    pod_cidr = "10.1.32.0/20"
    #},
    #{
    #    private_ip_address = "10.1.0.6"
    #    number_of_pods = 0
    #    pod_cidr = "10.1.48.0/20"
    #}
  ]
#Configuration for the k8s worker nodes
worker_nodes_config = [
    {
        private_ip_address = "10.1.0.7"
        number_of_pods = 30
        pod_cidr = "10.1.64.0/20"
    }#,
    #{
    #    private_ip_address = "10.1.0.8"
    #    number_of_pods = 30
    #    pod_cidr = "10.1.80.0/20"
    #},
    #{
    #    private_ip_address = "10.1.0.9"
    #    number_of_pods = 30
    #    pod_cidr = "10.1.96.0/20"
    #}
  ]
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
api_server_name = "k8s.cloudruler.io"
#Username of the admin user
admin_username = "cloudruleradmin"