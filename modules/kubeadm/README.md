sudo kubeadm config images pull
sudo kubeadm config print init-defaults
sudo kubeadm init --config /etc/kubeadm/config.yaml --v=10

sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps -a
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock logs CONTAINERID
sudo crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps -a | grep kube | grep -v pause

container-runtime=remote   --container-runtime-endpoint=<path>    --cgroup-driver  --cri-socket

sudo grep -i -n --color error /var/log/cloud-init.log
sudo grep -i -n --color warn /var/log/cloud-init.log
sudo grep -i -n --color error /var/log/cloud-init-output.log
sudo grep -i -n --color warn /var/log/cloud-init-output.log
sudo cat -n /var/log/cloud-init.log
sudo cat -n /var/log/cloud-init-output.log

sudo cat /etc/cni/net.d/10-azure.conflist
sudo cat /var/log/azure-vnet.log
sudo ls -la /opt/cni/bin

sudo systemctl status containerd
sudo journalctl -xeu containerd

sudo systemctl status kubelet
sudo journalctl -xeu kubelet

kubectl -n kube-system get deployments

#Check etcd. Run this from master.
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key

#Check containerd
crictl info

#Verify workers are bootstapped
kubectl get nodes

kubectl -n kube-system exec -it etcd-<Tab> -- sh

#Troubleshoot coredns
dig @<pod ip address> kubernetes.default.svc.cluster.local +noall +answer

##MANIFESTS
/etc/kubernetes/manifests/

Generated kubelet config yaml is at: /var/lib/kubelet/config.yaml
Generated kubelet flags is at: /var/lib/kubelet/kubeadm-flags.env


cat /var/lib/cloud/instance user-data.txt
cloud-init devel schema --config-file /var/lib/cloud/instance user-data.txt
cloud-init devel schema --config-file /mnt/c/Users/brian/git/cloudruler/infrastructure/sandbox/user-data-master-azure.yml

kubeadm token generate
kubeadm certs certificate-key


sudo cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sudo cat /etc/kubernetes/admin.conf
sudo cat /var/lib/kubelet/config.yaml

/var/lib/etcd

  client-certificate: /var/lib/kubelet/pki/kubelet-client-current.pem
  client-key: /var/lib/kubelet/pki/kubelet-client-current.pem


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

#Verify control plane is bootstrapped (run this from a master)
#This is deprecated and show unhealthy
kubectl get componentstatuses

###########RUN BOOTSTRAPPING OF WORKER NODES

controller-manager "http://127.0.0.1:10252/healthz" connection refused

/var/lib/kubelet/config.yaml


dig is the gold standard for debugging DNS
dig -p 1053 @localhost +noall +answer <name> <type>