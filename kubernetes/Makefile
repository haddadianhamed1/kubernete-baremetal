deps:
	apt-get update
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable"
	apt-get update
	apt-cache policy docker-ce
	apt-get install -y docker-ce
	swapoff -a
	apt-get install -y ebtables ethtool
	sed -i '/.swap.*/d' /etc/fstab

install:
	swapoff -a
	apt-get update && apt-get install -y apt-transport-https
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
	echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' >/etc/apt/sources.list.d/kubernetes.list
	apt-get update
	apt-get install -y kubelet kubeadm kubectl
install-master:
	cp kubeadm-master.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
	sed -i '/KUBELET_NETWORK_ARGS/d' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
	kubeadm init --apiserver-advertise-address=`ifconfig enp0s8 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'` --pod-network-cidr=192.168.0.0/16 > /vagrant/token.txt
	export KUBECONFIG=/etc/kubernetes/admin.conf
	echo export KUBECONFIG=/etc/kubernetes/admin.conf >> /etc/profile
install-network:
	kubectl get nodes
	kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml
	#kubectl apply -f /vagrant/kube-flannel.yml
install-minions:
	swapoff -a
	cp kubeadm-node.conf /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
	export hamed=`ifconfig enp0s8 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'`
	sed -i "s/HOSTNAME/"${hamed}/ /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
	cat /vagrant/token.txt  | grep kubeadm | grep join | xargs -L 1 xargs
