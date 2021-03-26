#Install azure CLI curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
#az login

#Certificate Authority
{

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "Cloud Ruler",
      "OU": "CA",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}

#Client and Server Certificates
{

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "system:masters",
      "OU": "Cloud Ruler",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

}

#The Kubelet Client Certificates
for instance in vm-k8s-worker-0 vm-k8s-worker-1 vm-k8s-worker-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "system:nodes",
      "OU": "Cloud Ruler",
      "ST": "Texas"
    }
  ]
}
EOF
EXTERNAL_HOSTNAME='k8s.cloudruler.io'
EXTERNAL_IP='52.152.96.240'

INTERNAL_IP=$(az vm list-ip-addresses -g rg-sandbox -n ${instance} --query "[0].virtualMachine.network.privateIpAddresses[0]")

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_HOSTNAME},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

#The Controller Manager Client Certificate
{

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "system:kube-controller-manager",
      "OU": "Cloud Ruler",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

}

#The Kube Proxy Client Certificate
{

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "system:node-proxier",
      "OU": "Cloud Ruler",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

}


#The Scheduler Client Certificate
{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "system:kube-scheduler",
      "OU": "Cloud Ruler",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}


#The Kubernetes API Server Certificate
{

KUBERNETES_PUBLIC_ADDRESS=$(az network public-ip show -g rg-connectivity -n pip-k8s --query "ipAddress" | sed 's/"//g')

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "Cloud Ruler",
      "OU": "Kubernetes",
      "ST": "Texas"
    }
  ]
}
EOF

INTERNAL_IP_0=$(az vm list-ip-addresses -g rg-sandbox -n vm-k8s-master-0 --query "[0].virtualMachine.network.privateIpAddresses[0]" | sed 's/"//g')
INTERNAL_IP_1=$(az vm list-ip-addresses -g rg-sandbox -n vm-k8s-master-1 --query "[0].virtualMachine.network.privateIpAddresses[0]" | sed 's/"//g')
INTERNAL_IP_2=$(az vm list-ip-addresses -g rg-sandbox -n vm-k8s-master-2 --query "[0].virtualMachine.network.privateIpAddresses[0]" | sed 's/"//g')

echo "INTERNAL_IP_0: $INTERNAL_IP_0"
echo "INTERNAL_IP_1: $INTERNAL_IP_1"
echo "INTERNAL_IP_2: $INTERNAL_IP_2"

HOSTNAMESLIST="vm-k8s-master-0,vm-k8s-master-1,vm-k8s-master-2,10.32.0.1,$INTERNAL_IP_0,$INTERNAL_IP_1,$INTERNAL_IP_2,$KUBERNETES_PUBLIC_ADDRESS,127.0.0.1,$KUBERNETES_HOSTNAMES"
echo "Host names: $HOSTNAMESLIST"



#HOSTNAMESLISTTWO=vm-k8s-master-0,vm-k8s-master-1,vm-k8s-master-2,10.32.0.1,$INTERNAL_IP_0,$INTERNAL_IP_1,$INTERNAL_IP_2,$KUBERNETES_PUBLIC_ADDRESS,127.0.0.1,$KUBERNETES_HOSTNAMES

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname="vm-k8s-master-0,vm-k8s-master-1,vm-k8s-master-2,k8s.cloudruler.io,10.32.0.1,$INTERNAL_IP_0,$INTERNAL_IP_1,$INTERNAL_IP_2,$KUBERNETES_PUBLIC_ADDRESS,127.0.0.1,$KUBERNETES_HOSTNAMES" \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

}


#The Service Account Key Pair
{

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Sugar Land",
      "O": "Cloud Ruler",
      "OU": "Kubernetes",
      "ST": "Texas"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

}

#Distribute the Client and Server Certificates
#for instance in vm-k8s-worker-0 vm-k8s-worker-1 vm-k8s-worker-2; do
#  scp -i ~/.ssh/cloudruleradmin -p 1 ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
#done

sudo scp -i ~/.ssh/cloudruleradmin -P 4 -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" ca.pem vm-k8s-worker-0-key.pem vm-k8s-worker-0.pem cloudruleradmin@k8s.cloudruler.io:~/
sudo scp -i ~/.ssh/cloudruleradmin -P 5 -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" ca.pem vm-k8s-worker-1-key.pem vm-k8s-worker-1.pem cloudruleradmin@k8s.cloudruler.io:~/
sudo scp -i ~/.ssh/cloudruleradmin -P 6 -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" ca.pem vm-k8s-worker-2-key.pem vm-k8s-worker-2.pem cloudruleradmin@k8s.cloudruler.io:~/
for instance in 1 2 3; do
    sudo scp -i ~/.ssh/cloudruleradmin -P ${instance} -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem cloudruleradmin@k8s.cloudruler.io:~/
done

#The kubelet Kubernetes Configuration File
for instance in vm-k8s-worker-0 vm-k8s-worker-1 vm-k8s-worker-2; do
  kubectl config set-cluster k8s.cloudruler.io \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=k8s.cloudruler.io \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done







#The kube-proxy Kubernetes Configuration File
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}



#The kube-controller-manager Kubernetes Configuration File
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
}

#The kube-scheduler Kubernetes Configuration File
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
}


#The admin Kubernetes Configuration File
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
}


#Distribute the Kubernetes Configuration Files
for instance in 1 2 3; do
  sudo scp -i ~/.ssh/cloudruleradmin -P ${instance} -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no"  admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig cloudruleradmin@k8s.cloudruler.io:~/
done

sudo scp -i ~/.ssh/cloudruleradmin -P 4 -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no"  vm-k8s-worker-0.kubeconfig kube-proxy.kubeconfig cloudruleradmin@k8s.cloudruler.io:~/
sudo scp -i ~/.ssh/cloudruleradmin -P 5 -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no"  vm-k8s-worker-1.kubeconfig kube-proxy.kubeconfig cloudruleradmin@k8s.cloudruler.io:~/
sudo scp -i ~/.ssh/cloudruleradmin -P 6 -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no"  vm-k8s-worker-2.kubeconfig kube-proxy.kubeconfig cloudruleradmin@k8s.cloudruler.io:~/

#Generate encryption key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

#Encryption config file
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

#Distribute encryption config to masters
for instance in 1 2 3; do
  sudo scp -i ~/.ssh/cloudruleradmin -P ${instance} -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no"  encryption-config.yaml cloudruleradmin@k8s.cloudruler.io:~/
done

##########RUN BOOTSTRAPPING OF ETCD ON THE WORKERS

#Verify etcd
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem

##############RUN BOOTSTRAPPING OF CONTROL PLANE

#Verify control plane is bootstrapped (run this from a master)
kubectl get componentstatuses --kubeconfig admin.kubeconfig

###########RUN BOOTSTRAPPING OF WORKER NODES

#Verify workers are bootstapped (run this from a master)
kubectl get nodes --kubeconfig admin.kubeconfig

##Configuring kubectl for Remote Access
#Generate a kubeconfig file suitable for authenticating as the admin user:
{

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
}

#Check the health of the remote Kubernetes cluster:
kubectl get componentstatuses

#List the nodes in the remote Kubernetes cluster:
kubectl get nodes

#Deploy the coredns cluster add-on:
kubectl apply -f ./coredns-1.7.0.yaml

#List the pods created by the kube-dns deployment:
kubectl get pods -l k8s-app=kube-dns -n kube-system

#See "systemctl status etcd.service" and "journalctl -xe" for details.
#systemctl status etcd.service
#journalctl -xe



sudo ETCDCTL_API=3 etcdctl get \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem\
  /registry/secrets/default/kubernetes-the-hard-way | hexdump -C
