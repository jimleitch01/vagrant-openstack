#!/bin/bash
keystonerc_infra
set -x
set -e
systemctl stop NetworkManager
systemctl disable NetworkManager
systemctl enable network
sh -c 'echo proxy=http://10.0.2.2:3128 >> /etc/yum.conf'
yum install  --disableplugin=fastestmirror -y https://rdoproject.org/repos/rdo-release.rpm
yum install  --disableplugin=fastestmirror -y openstack-packstack
yum install  --disableplugin=fastestmirror -y telnet tcpdump

INTERNALIP=$(ifconfig | grep "inet" | grep "10.0.2" | awk '{ print $2 }')
EXTERNALIP=$(ifconfig | grep "inet" | grep "192.168" | awk '{ print $2 }')
/usr/bin/packstack --gen-answer-file=/tmp/answers
sed -i "s/CONFIG_PROVISION_DEMO=y/CONFIG_PROVISION_DEMO=n/g" /tmp/answers
sed -i "s/CONFIG_CEILOMETER_INSTALL=y/CONFIG_CEILOMETER_INSTALL=n/g" /tmp/answers
sed -i "s/$INTERNALIP/$EXTERNALIP/g" /tmp/answers
sed -i "s/CONFIG_NAGIOS_INSTALL=y/CONFIG_NAGIOS_INSTALL=n/g" /tmp/answers > /tmp/answers-external
sed -i "s/CONFIG_DEBUG_MODE=n/CONFIG_DEBUG_MODE=y/g" /tmp/answers > /tmp/answers-external

/usr/bin/packstack --answer-file=/tmp/answers
echo ""
echo "**** Logins ******"
echo ""
cat /root/keystonerc_admin
echo ""

EXTERNALDEV=$(ifconfig | grep -B 1  $EXTERNALIP | head -1 | cut -f1 -d":")
EXTERNALMAC=$(ifconfig | grep -A 3 $EXTERNALDEV | tail -1 | awk '{print $2}')
EXTERNALBASE=$(echo $EXTERNALIP | cut -f1,2,3 -d".")
EXTERNALNWADDR=$(echo $EXTERNALIP | cut -f1,2,3 -d".").0/24
EXTERNALGW=$(echo $EXTERNALIP | cut -f1,2,3 -d".").1

cat > /etc/sysconfig/network-scripts/ifcfg-br-ex << EOSCRIPT
DEVICE=br-ex
DEVICETYPE=ovs
TYPE=OVSBridge
BOOTPROTO=static
IPADDR=$EXTERNALIP
NETMASK=255.255.255.0
GATEWAY=$EXTERNALGW
DNS1=8.8.8.8
ONBOOT=yes
EOSCRIPT

cat > /etc/sysconfig/network-scripts/ifcfg-$EXTERNALDEV << EOSCRIPT
DEVICE=$EXTERNALDEV
HWADDR=$EXTERNALMAC
TYPE=OVSPort
DEVICETYPE=ovs
OVS_BRIDGE=br-ex
ONBOOT=yes
EOSCRIPT

openstack-config --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings extnet:br-ex
openstack-config --set /etc/neutron/plugin.ini ml2 type_drivers vxlan,flat,vlan

service network restart
service neutron-openvswitch-agent restart
service neutron-server restart

. ~/keystonerc_admin
neutron net-create external_network --provider:network_type flat --provider:physical_network extnet  --router:external --shared

neutron subnet-create --name public_subnet --enable_dhcp=False --allocation-pool=start=$EXTERNALBASE.100,end=$EXTERNALBASE.150 --gateway=$EXTERNALGW external_network $EXTERNALNWADDR
neutron router-create router1
neutron router-gateway-set router1 external_network

neutron net-create private_network
neutron subnet-create --name private_subnet private_network 192.168.100.0/24
neutron router-interface-add router1 private_subnet

xzcat /vagrant/files/CentOS-6-x86_64-GenericCloud.qcow2.xz | glance image-create --name='CentOS6' --visibility=public  --container-format=bare  --disk-format=qcow2
xzcat /vagrant/files/CentOS7-rootlogin.xz | glance image-create --name='CentOS7-rootlogin' --visibility=public  --container-format=bare  --disk-format=qcow2

keystone tenant-create --name infra --description "infra tenant" --enabled true
keystone user-create --name infra --tenant infra --pass "infra" --email bar@corp.com --enabled true

cp ~/keystonerc_admin ~/keystonerc_infra
sed -i "s/admin=y/infra=n/g" ~/keystonerc_infra
echo export OS_PASSWORD=infra >> keystonerc_infra
