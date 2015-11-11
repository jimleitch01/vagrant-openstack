# -*- mode: ruby -*-
# vi: set ft=ruby :
# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!

VAGRANTFILE_API_VERSION = "2"
BOX_NAME = 'bento/centos-7.1'
BOX_IP = '192.168.10.10'
HOSTNAME = 'rdo'
DOMAIN   = 'vagrant.dev'
Vagrant.require_version '>= 1.4.0'
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

config.vm.box = BOX_NAME

config.vm.network :private_network, ip: BOX_IP
config.vm.network "forwarded_port", guest: 80, host: 8000
config.vm.network "forwarded_port", guest: 5000, host: 5000

config.vm.host_name = HOSTNAME + '.' + DOMAIN

config.vm.synced_folder "./", "/vagrant", id: "vagrant-root",
    owner: "vagrant",
    group: "nobody",
    mount_options: ["dmode=777,fmode=755"]

config.vm.provider "virtualbox" do |v|
  v.memory = 8192
  v.cpus = 4
end

config.vm.provider "vmware_fusion" do |v|
  v.vmx["memsize"] = "8192"
  v.vmx["numvcpus"] = "4"
end



config.vm.provision "shell",
    inline: "ps -aef"
end
