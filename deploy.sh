apt-get update
apt-get install -qy docker.io
apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' >/etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
swapoff -a


https://www.youtube.com/watch?v=6xJwQgDnMFE

for i in `(docker ps -aq)`;do docker logs $i; done

E0129 23:32:37.007880       1 reflector.go:205] k8s.io/kubernetes/vendor/k8s.io/client-go/informers/factory.go:86: Failed to list *v1.ReplicationController: replicationcontrollers is forbidden: User "system:kube-scheduler" cannot list replicationcontrollers at the cluster scope
