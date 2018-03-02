# kubernete-baremetal
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-reload

https://github.com/aidanns/vagrant-reload


change node hostname
use CALICO

kubeadm init --apiserver-advertise-address=`ifconfig enp0s8 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'` --pod-network-cidr=192.168.0.0/16 > /vagrant/token.txt

on nodes:
vi /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
Environment="KUBELET_EXTRA_ARGS=--hostname-override=10.8.0.21"


on master:
#remove this line
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin"


# TODO
add labels to nodes
https://github.com/kubernetes/kubeadm/issues/202
```
cat > /etc/systemd/system/kubelet.service.d/20-labels-taints.conf <<EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--node-labels=label1=value1,label2=value2 --register-with-taints=foo=bar:NoSchedule"
```

write chef recipes

all nodes use tls to communicate 
