#!/bin/bash
read -p "请输入主机名:" Hostname
read -p "请输入IP地址的主机位:" HostIP

echo $HostIP $Hostname  >> /etc/hosts

systemctl stop firewalld.service
systemctl disable firewalld.service

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

groupadd oinstall
groupadd dba
useradd -g oinstall -G dba oracle
echo oracleadmin | passwd oracle --stdin

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
export ORACLE_BASE=/home/u01/app/oracle/product/11.2.0
export ORACLE_HOME=/home/u01/app/oracle/product/11.2.0/db_1
export ORACLE_SID=xtd
export LD_LIBRARY_PATH=/home/u01/app/oracle/product/11.2.0/db_1/lib
export PATH=/home/u01/app/oracle/product/11.2.0/db_1/bin:.:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/oracle/.local/bin:/home/oracle/bin
EOF

cat <<EOF >> /etc/pam.d/login

session    required     /lib/security/pam_limits.so 
session    required     pam_limits.so
EOF

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
cp ./CentOS-Media.repo  /etc/yum.repos.d
umount /media
mount -o loop /home/CentOS*.iso  /media/
rpm --import /media/RPM-GPG-KEY-CentOS-*

yum install gcc make binutils gcc-c++ compat-libstdc++-33elfutils-libelf-devel elfutils-libelf-devel-static libaio libaio-develnumactl-devel sysstat unixODBC unixODBC-devel pcre-devel libaio-dev* elfutils*  –y

rpm -ivh ./pdksh-5.2.14-37.el5_8.1.x86_64.rpm
rpm -ivh ./compat-libstdc++-33-3.2.3-69.el6.x86_64.rpm

cp -r ./bin /usr/local/
chown -R oracle:root /usr/local/bin/
cp ./oraInst.loc /etc/
cp ./oratab /etc/
chown -R oracle:oinstall /etc/oratab

tar zxvf ./u01_Template.tar.gz -C /home/


