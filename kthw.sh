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
      "O": "Kubernetes",
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

INTERNAL_IP='10.1.1.4'

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

KUBERNETES_PUBLIC_ADDRESS='52.152.96.240'

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
      "O": "Kubernetes",
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
  -hostname=10.32.0.1,10.1.1.4,10.1.1.5,10.1.1.6,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
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
      "O": "Kubernetes",
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

#Execute on every node:
#Download and Install the etcd Binaries
wget -q --show-progress --https-only --timestamping "https://github.com/etcd-io/etcd/releases/download/v3.4.10/etcd-v3.4.10-linux-amd64.tar.gz"

{
  tar -xvf etcd-v3.4.10-linux-amd64.tar.gz
  sudo mv etcd-v3.4.10-linux-amd64/etcd* /usr/local/bin/
}

#ssh -i ~/.ssh/cloudruleradmin -p 1 -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" cloudruleradmin@k8s.cloudruler.io command


#Configure etcd server
{
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo chmod 700 /var/lib/etcd
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
}

#Use the Azure Instance Metadata Service to get the private IP
sudo apt-get install -y jq
INTERNAL_IP=$(curl --silent -H Metadata:True --noproxy "*" http://169.254.169.254/metadata/instance?api-version=2020-09-01 | jq -r '.["network"]["interface"][0]["ipv4"]["ipAddress"][0]["privateIpAddress"]')

ETCD_NAME=$(hostname -s)

#Create the etcd.service systemd unit file:
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster vm-k8s-master-0=https://10.1.1.4:2380,vm-k8s-master-1=https://10.1.1.35:2380,vm-k8s-master-2=https://10.1.1.66:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


{
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
}

##################END COMMANDS WHICH MUST BE EXECUTED ON EVERY MASTER NODE################


#See "systemctl status etcd.service" and "journalctl -xe" for details.
#systemctl status etcd.service
#journalctl -xe

etcd[25550]: rejected connection from "10.1.1.36:33234" (error "tls: \"10.1.1.36\" does not match any of DNSNames [\"kubernetes\" \"kubernetes.default\" \"kubernetes.default.svc\" \"kubernetes.default.svc.cluster\" \"kubernetes.svc.cluster.local\"] (lookup kubernetes.svc.cluster.local on 127.0.0.53:53: server misbehaving)", ServerName "", IPAdd
etcd[25550]: rejected connection from "10.1.1.67:52068" (error "tls: \"10.1.1.67\" does not match any of DNSNames [\"kubernetes\" \"kubernetes.default\" \"kubernetes.default.svc\" \"kubernetes.default.svc.cluster\" \"kubernetes.svc.cluster.local\"] (lookup kubernetes.svc.cluster.local on 127.0.0.53:53: server misbehaving)", ServerName "", IPAdd
etcd[25550]: rejected connection from "10.1.1.36:33242" (error "tls: \"10.1.1.36\" does not match any of DNSNames [\"kubernetes\" \"kubernetes.default\" \"kubernetes.default.svc\" \"kubernetes.default.svc.cluster\" \"kubernetes.svc.cluster.local\"] (lookup kubernetes.svc.cluster.local on 127.0.0.53:53: server misbehaving)", ServerName "", IPAdd
etcd[25550]: rejected connection from "10.1.1.36:33244" (error "tls: \"10.1.1.36\" does not match any of DNSNames [\"kubernetes\" \"kubernetes.default\" \"kubernetes.default.svc\" \"kubernetes.default.svc.cluster\" \"kubernetes.svc.cluster.local\"] (lookup kubernetes.svc.cluster.local on 127.0.0.53:53: server misbehaving)", ServerName "", IPAdd
etcd[25550]: rejected connection from "10.1.1.67:52078" (error "tls: \"10.1.1.67\" does not match any of DNSNames [\"kubernetes\" \"kubernetes.default\" \"kubernetes.default.svc\" \"kubernetes.default.svc.cluster\" \"kubernetes.svc.cluster.local\"] (lookup kubernetes.svc.cluster.local on 127.0.0.53:53: server misbehaving)", ServerName "", IPAdd
etcd[25550]: rejected connection from "10.1.1.67:52076" (error "tls: \"10.1.1.67\" does not match any of DNSNames [\"kubernetes\" \"kubernetes.default\" \"kubernetes.default.svc\" \"kubernetes.default.svc.cluster\" \"kubernetes.svc.cluster.local\"] (lookup kubernetes.svc.cluster.local on 127.0.0.53:53: server misbehaving)", ServerName "", IPAdd
etcd[25550]: rejected connection from "10.1.1.36:33250" (error "tls: \"10.1.1.36\" does not match any of DNSNames [\"kubernetes\" \"kubernetes.default\" \"kubernetes.default.svc\" \"kubernetes.default.svc.cluster\" \"kubernetes.svc.cluster.local\"] (lookup kubernetes.svc.cluster.local on 127.0.0.53:53: server misbehaving)", ServerName "", IPAdd
etcd[25550]: rejected connection from "10.1.1.36:33252" (error "tls: \"10.1.1.36\" does not match any of DNSNames [\"kubernetes\" \"kubernetes.default\" \"kubernetes.default.svc\" \"kubernetes.default.svc.cluster\" \"kubernetes.svc.cluster.local\"] (lookup kubernetes.svc.cluster.local on 127.0.0.53:53: server misbehaving)", ServerName "", IPAdd
etcd[25550]: rejected connection from "10.1.1.67:52084" (error "tls: \"10.1.1.67\" does not match any of DNSNames [\"kubernetes\" \"kubernetes.default\" \"kubernetes.default.svc\" \"kubernetes.default.svc.cluster\" \"kubernetes.svc.cluster.local\"] (lookup kubernetes.svc.cluster.local on 127.0.0.53:53: server misbehaving)", ServerName "", IPAdd
etcd[25550]: rejected connection from "10.1.1.67:52086" (error "tls: \"10.1.1.67\" does not match any of DNSNames [\"kubernetes\" \"kubernetes.default\" \"kubernetes.default.svc\" \"kubernetes.default.svc.cluster\" \"kubernetes.svc.cluster.local\"] (lookup kubernetes.svc.cluster.local on 127.0.0.53:53: server misbehaving)", ServerName "", IPAdd
