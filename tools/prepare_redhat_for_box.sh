#!/bin/bash +x

# This script should help to prepare RedHat and RedHat like OS (CentOS,
# Scientific Linux, ...) for Vagrant usage.

# To create new box image, just install minimal base system in VM. Then upload
# this script to the VM and run it. After script has finished, halt the machine
# and then create an oVirt  template, which will be used for creating new
# vagrant machines.


# We need a hostname.
if [ $# -ne 1 ]; then
  echo "Usage: $0 <hostname>"
  echo "Hostname should be in format vagrant-[os-name], e.g. vagrant-redhat63."
  exit 1
fi


# On which version of RedHet are we running?
RHEL_MAJOR_VERSION=$(sed 's/.*release \([0-9]\)\..*/\1/' /etc/redhat-release)
if [ $? -ne 0 ]; then
  echo "Is this a RedHat distro?"
  exit 1
fi
echo "* Found RedHat ${RHEL_MAJOR_VERSION} version."


# Setup hostname vagrant-something.
FQDN="$1.vagrantup.com"
if grep '^HOSTNAME=' /etc/sysconfig/network > /dev/null; then
  sed -i 's/HOSTNAME=\(.*\)/HOSTNAME='${FQDN}'/' /etc/sysconfig/network
else
  echo "HOSTNAME=${FQDN}" >> /etc/sysconfig/network
fi


# Enable EPEL and Puppet repositories.
if [ $RHEL_MAJOR_VERSION -eq 5 ]; then
  yum install -y \
    http://ftp.astral.ro/mirrors/fedora/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm \
    https://yum.puppetlabs.com/el/5/products/x86_64/puppetlabs-release-5-7.noarch.rpm
else
  yum install -y \
    http://ftp.astral.ro/mirrors/fedora/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm \
    https://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm
fi

# Install some required software.
yum -y install openssh-server openssh-clients sudo curl \
ruby ruby-devel make gcc rubygems rsync puppet ovirt-guest-agent
chkconfig sshd on

# Users, groups, passwords and sudoers.
grep 'vagrant' /etc/passwd > /dev/null
if [ $? -ne 0 ]; then
  echo '* Creating user vagrant.'
  useradd vagrant
  echo 'vagrant' | passwd --stdin vagrant
fi
grep '^admin:' /etc/group > /dev/null || groupadd admin
usermod -G admin vagrant

echo 'Defaults    env_keep += "SSH_AUTH_SOCK"' >> /etc/sudoers
echo '%admin ALL=NOPASSWD: ALL' >> /etc/sudoers
sed -i 's/Defaults\s*requiretty/Defaults !requiretty/' /etc/sudoers


# SSH setup
# Add Vagrant ssh key for root accout.
sed -i 's/.*UseDNS.*/UseDNS no/' /etc/ssh/sshd_config

vagrant_home=/home/vagrant
[ -d $vagrant_home/.ssh ] || mkdir $vagrant_home/.ssh
chmod 700 $vagrant_home/.ssh
curl https://raw2.github.com/mitchellh/vagrant/master/keys/vagrant.pub > $vagrant_home/.ssh/authorized_keys
chmod 600 $vagrant_home/.ssh/authorized_keys
chown -R vagrant:vagrant $vagrant_home/.ssh


# Disable firewall and switch SELinux to permissive mode.
chkconfig iptables off
chkconfig ip6tables off
sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/sysconfig/selinux
[ -f /etc/selinux/config ] && sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config


# Networking setup..

# Problem situation: Two interfaces are connected to same network. One interface
# wants to renew DHCP lease and asks server for address. DHCPACK message from
# server arrives, client moves to BOUND state. The client performs a check on
# the suggested address to ensure that the address is not already in use. On
# arping for specified IP address, other interface replies and that's why
# dhclient-script replies with DHCPDECLINE message. (See RFC2131, 4.4.1.).
# Solution: Set sysctl to reply only if the target IP address is local address
# configured on the incoming interface. (See kernel documentation 
# Documentation/networking/ip-sysctl.txt)
set_sysctl()
{
  grep $1 /etc/sysctl.conf > /dev/null
  [ $? -eq 0 ] && sed -i '/'$1'/d' /etc/sysctl.conf
  echo "$1 = $2" >> /etc/sysctl.conf
}
set_sysctl 'net.ipv4.conf.all.arp_ignore' 1
set_sysctl 'net.ipv4.conf.all.arp_announce' 2
set_sysctl 'net.ipv4.conf.all.rp_filter' 3

# Don't fix ethX names to hw address.
rm -f /etc/udev/rules.d/*persistent-net.rules
rm -f /etc/udev/rules.d/*-net.rules
rm -fr /var/lib/dhclient/*

# Interface eth0 should always get IP address via dhcp.
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="dhcp"
ONBOOT="yes"
NM_CONTROLLED="no"
EOF


# Do some cleanup..
rm -f ~root/.bash_history
yum clean all
