#!/bin/bash


##############
#####Configuring the system
##############
echo "准备配置系统基本参数......"
sleep 5
sed -i '/yd2nc/d' /etc/hosts
sed -i '/yd2nc/d' /etc/hosts
Hostname="yd2nc"

read -p "请输入公安网IP地址:" HostIPg
echo $HostIPg $Hostname  >> /etc/hosts

#read -p "请输入考试专网IP地址:" HostIPz
echo "192.168.0.1" $Hostname  >> /etc/hosts

systemctl stop firewalld.service
systemctl disable firewalld.service

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

sed -i '/Port    22505/d'  /etc/ssh/sshd_config 
sed -i '/Port    22/d'  /etc/ssh/sshd_config 
echo "Port    22505"   >>  /etc/ssh/sshd_config 
echo "Port    22"   >>  /etc/ssh/sshd_config 
#############
###install oracle db
#############
echo "准备安装数据库......"
sleep 5
groupadd oinstall
groupadd dba
useradd -g oinstall -G dba oracle
echo 'Suntendy@505!' | passwd oracle --stdin

mv /home/u01 /home/u01_`date +%H%M%S`
mkdir -p /home/u01/app
chown -R oracle:oinstall /home/u01/

sed -i '/export PATH/d' /home/oracle/.bash_profile
sed -i '/export ORACLE_BASE/d' /home/oracle/.bash_profile
sed -i '/export ORACLE_HOME/d' /home/oracle/.bash_profile
sed -i '/export ORACLE_SID/d' /home/oracle/.bash_profile
sed -i '/export LD_LIBRARY_PATH/d' /home/oracle/.bash_profile
sed -i '/export PATH/d' /home/oracle/.bash_profile

cat <<EOF >> /home/oracle/.bash_profile

export PATH
export ORACLE_BASE=/home/u01/app/oracle
export ORACLE_HOME=/home/u01/app/oracle/product/11.2.0/db_1
export ORACLE_SID=nc
export PATH=\$PATH:\$HOME/bin:\$ORACLE_HOME/bin
EOF

sed -i '/\/lib\/security\/pam_limits.so/d' /etc/pam.d/login
sed -i '/pam_limits.so/d' /etc/pam.d/login

cat <<EOF >> /etc/pam.d/login

session    required     /lib/security/pam_limits.so 
session    required     pam_limits.so
EOF



sed -i '/kernel.shmmax/d' /etc/sysctl.conf
sed -i '/kernel.shmall/d' /etc/sysctl.conf
sed -i '/fs.file-max/d' /etc/sysctl.conf
sed -i '/fs.aio-max-nr/d' /etc/sysctl.conf
sed -i '/kernel.shmmni/d' /etc/sysctl.conf
sed -i '/kernel.sem/d' /etc/sysctl.conf
sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
sed -i '/net.core.rmem_default/d' /etc/sysctl.conf
sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
sed -i '/net.core.wmem_default/d' /etc/sysctl.conf
sed -i '/net.core.wmem_max/d' /etc/sysctl.conf


cat <<EOF >> /etc/sysctl.conf 

kernel.shmmax = 68719476736
kernel.shmall = 4294967296
fs.file-max = 6815744
fs.aio-max-nr = 1048576
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 4194304
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576

EOF

sysctl -p 

cat <<EOF >> /etc/security/limits.conf

oracle soft nproc 16384
oracle hard nproc 16384
oracle soft nofile 65536
oracle hard nofile 65536

EOF

cat <<EOF >> /etc/profile

if [ $USER = "oracle" ]||[ $USER = "grid" ]; then
   if [ $SHELL = "/bin/ksh" ]; then
      ulimit -p 16384
      ulimit -n 65536
   else
      ulimit -u 16384 -n 65536
   fi
fi

EOF
source /etc/profile
rm -rf /etc/yum.repos.d/*
cp ./conf/CentOS-Stream-Media.repo  /etc/yum.repos.d
umount /media
mount -o loop ./ISO_TEMPLATE/CentOS-Stream-*.iso /media/
rpm --import /media/RPM-GPG-KEY-CentOS-*

yum install gcc make binutils gcc-c++ compat-libstdc++-33elfutils-libelf-devel elfutils-libelf-devel-static libaio libaio-develnumactl-devel sysstat unixODBC unixODBC-devel pcre-devel libaio-dev* elfutils* -y

rpm -ivh ./rpm_packages/pdksh-5.2.14-37.el5_8.1.x86_64.rpm
rpm -ivh ./rpm_packages/compat-libstdc++-33-3.2.3-69.el6.x86_64.rpm

unalias cp
cp -rf ./DB_TEMPLATE/bin/ /usr/local/
chown -R oracle:root /usr/local/bin/
cp -rf ./DB_TEMPLATE/oraInst.loc /etc/
cp -rf ./DB_TEMPLATE/oratab /etc/
chown -R oracle:oinstall /etc/oratab /etc/oraInst.loc

#########download db
yum install wget* curl* telnet* -y
#########ftp server
rm -rf ./DB_TEMPLATE/u01_2022.tar.gz
echo "准备下载数据"
wget --ftp-user=deploy --ftp-password=Deploy#2022 196.128.1.101:/home/deploy/u01_2022.tar.gz -P ./DB_TEMPLATE/
echo "完成数据下载"
sleep 10
tar zxvf ./DB_TEMPLATE/u01_2022.tar.gz -C /home/
###################
######install websphere
##################
echo "准备安装应用 ......"
sleep 10
mv /home/was8552  /home/was8552_`date +%H%M%S`
rm -rf ./WAS_TEMPLATE/was8552_2022.tar.gz
wget --ftp-user=deploy --ftp-password=Deploy#2022 196.128.1.101:/home/deploy/was8552_2022.tar.gz -P ./WAS_TEMPLATE
tar zxvf ./WAS_TEMPLATE/was8552_2022.tar.gz -C /home/

#############
#####create kvm
############
cp -rf ./conf/ifcfg-br0  /etc/sysconfig/network-scripts/
netfile=`grep -l "192.168.0.1"  /etc/sysconfig/network-scripts/*`
sed -i 's/PREFIX=24/#PREFIX=24/g' $netfile
sed -i 's/IPADDR=192.168.0.1/#IPADDR=192.168.0.1/g' $netfile
sed -i 's/NETMASK=255.255.255.0/#NETMASK=255.255.255.0/g' $netfile
echo "BRIDGE=\"br0\""  >>  $netfile

####yum install -y *kvm*  *virsh* virt-* libvirt qemu-img
yum install -y   *virsh* virt-* libvirt qemu-img
systemctl enable --now libvirtd
systemctl start libvirtd

#####IMP template  NC
rm -rf /home/kvm_data
rm -rf /etc/libvirt/qemu/centos7.0.xml
mkdir -p /home/kvm_data/
echo "准备创建工作站模板......"
#cp ./NC_TEMPLATE/nc_server01.qcow2 /home/kvm_data/
tar zxvf ./NC_TEMPLATE/nc_template.tar.gz -C /home/kvm_data/
mv /home/kvm_data/nc_kvm/nc_server01.qcow2 /home/kvm_data/nc_kvm/centos7.0.xml /home/kvm_data/
cp /home/kvm_data/centos7.0.xml /etc/libvirt/qemu
virsh define /etc/libvirt/qemu/centos7.0.xml
virsh start centos7.0


echo "运行已结束请重启服务器，输入命令  reboot"
