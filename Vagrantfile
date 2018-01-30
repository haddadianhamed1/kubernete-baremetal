# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-16.04"

  # Kubernetes Master
  config.vm.define "master" do |c1|
    c1.vm.network  "private_network", ip: "10.8.0.15"
    c1.vm.host_name = "master"

    #c1.vm.provision "shell", inline: "cd /vagrant/kubernetes && make deps"
    #c1.vm.provision :reload
    #c1.vm.provision "shell", inline: "cd /vagrant/kubernetes && make install"
    c1.vm.provision "shell", inline: "cd /vagrant/kubernetes && make deps install install-master"
    c1.vm.provision "shell", inline: "cd /vagrant/kubernetes && make install-network"

    c1.vm.provider "virtualbox" do |vb|
     vb.memory = 4096
     vb.cpus = 2
    end
  end

  # Nodes/ Minions
  (1..2).each do |d|
    config.vm.define "docker#{d}" do |node|
      node.vm.network "private_network", ip: "10.8.0.2#{d}" # 10.7.0.21, 10.7.0.22, 10.7.0.23
      node.vm.host_name = "docker#{d}"

      #node.vm.provision "shell", inline: "cd /vagrant/kubernetes && make deps"
      #node.vm.provision "shell", inline: "hostnamectl set-hostname node1 & /bin/bash"
      node.vm.provision "shell", inline: "cd /vagrant/kubernetes && make deps install install-minions"
      #node.vm.provision :reload
      #node.vm.provision "shell", inline: "cd /vagrant/kubernetes && make install"      #node.vm.provision "shell", inline: "reboot"
      #node.vm.provision "docker" # Just install it
      config.vm.provider "virtualbox" do |v|
        v.memory = 1024
        v.cpus = 1
      end
    end
  end
end
