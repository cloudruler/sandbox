sudo kubeadm config images pull --cri-socket unix:///run/containerd/containerd.sock
sudo kubeadm config print init-defaults --cri-socket unix:///run/containerd/containerd.sock
sudo kubeadm init --control-plane-endpoint=k8s.cloudruler.io --cri-socket unix:///run/containerd/containerd.sock --config /etc/kubeadm/kubeadm-config.yml --v=10 --pod-network-cidr 10.2.0.0/24
sudo kubeadm init --config /etc/kubeadm/kubeadm-config.yml --cri-socket unix:///run/containerd/containerd.sock

sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock logs CONTAINERID
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps -a | grep kube | grep -v pause

container-runtime=remote   --container-runtime-endpoint=<path>    --cgroup-driver  --cri-socket

sudo grep -i -n --color error /var/log/cloud-init.log
sudo grep -i -n --color warn /var/log/cloud-init.log
sudo grep -i -n --color error /var/log/cloud-init-output.log
sudo grep -i -n --color warn /var/log/cloud-init-output.log
sudo cat -n /var/log/cloud-init.log
sudo cat -n /var/log/cloud-init-output.log








sudo systemctl status kubelet
sudo journalctl -xeu kubelet

cat /var/lib/cloud/instance user-data.txt
cloud-init devel schema --config-file /var/lib/cloud/instance user-data.txt
cloud-init devel schema --config-file /mnt/c/Users/brian/git/cloudruler/infrastructure/sandbox/user-data-master-azure.yml

kubeadm token generate
kubeadm certs certificate-key

https://k8s.cloudruler.io:6443/api/v1/pods?fieldSelector=spec.nodeName%3Dvm-k8s-master000000&limit=500&resourceVersion=0
https://k8s.cloudruler.io:6443/api/v1/services?limit=500&resourceVersion=0
https://k8s.cloudruler.io:6443/api/v1/namespaces/default/events

kubelet "times out" trying to register the node with the API server
HTTP get and post to API server fails from kubelet
i can curl API server from the node
try setting configuration values
try connecting kubectl to the API server


sudo iptables -t nat -A POSTROUTING -m iprange ! --dst-range 168.63.129.16 -m addrtype ! --dst-type local ! -d 10.1.0.0/16 -j MASQUERADE

--cloud-provider=azure

#Check etcd
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem


#Verify control plane is bootstrapped (run this from a master)
#This is deprecated and show unhealthy
kubectl get componentstatuses

###########RUN BOOTSTRAPPING OF WORKER NODES

#Verify workers are bootstapped
kubectl get nodes


controller-manager "http://127.0.0.1:10252/healthz" connection refused

/var/lib/kubelet/config.yaml