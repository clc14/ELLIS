#!/bin/bash

# Name: ELLIS
# Description: A script is to quickly and easily setup a pre-configured lab 
#   environment useful for studying to obtain enterprise Linux certifications.
# Author: Sean O'Connell <sean@sdoconnell.net>
# Version: 0.2 2017-03-06
# License: GPLv2 (https://www.gnu.org/licenses/gpl-2.0.en.html)

ELLISVER="0.2"

REQVER="7.3"
CHECKVER=true

## This script is tested only against the current version of CentOS.
## If you want to run this script on an unsupported version of CentOS
## you can disable version checking by uncommenting the following line.
#CHECKVER=false

##################################
## Begin user-defined variables ##
##################################

## By default, this script creates everything under the "example.com" name space.

LABHOST="lab"
LABDOMAIN="example.com"
SMBWKGP="EXAMPLE"
KRB5REALM="EXAMPLE.COM"
KRB5PASSWD="admin"
LDAPPASSWD="admin"
ADMNPASSWD="admin"
USERPASSWD="password"
VMROOTPASS="admin"

## LDAP parameters
LDAPPATH="dc=example,dc=com"
LDAPBASE="example"

## Certificate fields
CERTCNTRY="US"
CERTSTATE="North Carolina"
CERTLOC="Charlotte"
CERTORG="Example, Inc."
CERTOU="Enterprise Linux Lab"
CERTCN="$LABHOST.$LABDOMAIN"
CERTEMAIL="lab@$LABDOMAIN"
CERTPASSWD="admin"

## Kernel update URL - this kernel should be newer than the one on the installation media
KERNUPDURL="http://mirror.centos.org/centos-7/7/updates/x86_64/Packages/kernel-3.10.0-514.10.2.el7.x86_64.rpm"

################################
## End user-defined variables ## 
################################

clear
echo " "
echo "ELLIS: Enterprise Linux Lab Installer Script ver. $ELLISVER"
echo " "

#########################
## Begin sanity checks ##
#########################

## Check to make sure we're running as root

if [ "$(whoami)" != "root" ]; then
    echo "ERROR: Insufficient permissions: This setup script must be run as root." >&2;
    exit 1;
fi

## Check to make sure we're running CentOS 7.2 or 7.3

if [ -f /etc/redhat-release ]; then
  OS_MAJOR=$(rpm -qa \*-release | grep centos | cut -d"-" -f3);
  OS_MINOR=$(rpm -qa \*-release | grep centos | cut -d"-" -f4 | cut -d"." -f1);
  OS_VERSION=$OS_MAJOR.$OS_MINOR;
  if [ "$CHECKVER" == true ] && [ "$OS_VERSION" != "$REQVER" ]; then
      echo "ERROR: Incompatible version: This setup script is for CentOS $REQVER only." >&2;
      exit 1;
  fi
else
    echo "ERROR: Incompatible version: This setup script is for CentOS only." >&2;
    exit 1;
fi

#######################
## End sanity checks ##
#######################

## Pause before proceeding
echo "Setup will begin in 10 seconds. Hit CTRL-C to cancel..."
sleep 10

#######################
## Begin basic setup ##
#######################

## Set the system hostname
hostnamectl set-hostname $LABHOST

## Setup required /etc/hosts records
echo "192.168.201.1   $LABHOST.$LABDOMAIN $LABHOST" >> /etc/hosts
echo "192.168.201.100 server0.$LABDOMAIN server0" >> /etc/hosts
echo "192.168.201.101 server1.$LABDOMAIN server1" >> /etc/hosts
echo "192.168.201.102 server2.$LABDOMAIN server2" >> /etc/hosts

## Create NFS home root
mkdir /home/guests
restorecon -Rv /home/guests

## Create lab users
useradd -d /home/guests/ldapuser01 -u 2001 ldapuser01
useradd -d /home/guests/ldapuser02 -u 2002 ldapuser02
echo password | passwd --stdin ldapuser01
echo password | passwd --stdin ldapuser02

## Add dummy files and directories to homes
echo "File1 contents" > /home/guests/ldapuser01/file1
echo "File2 contents" > /home/guests/ldapuser01/file2
echo "File3 contents" > /home/guests/ldapuser01/file3
mkdir /home/guests/ldapuser01/{dir1,dir2,dir3}
chown -R ldapuser01:ldapuser01 /home/guests/ldapuser01

echo "File1 contents" > /home/guests/ldapuser02/file1
echo "File2 contents" > /home/guests/ldapuser02/file2
echo "File3 contents" > /home/guests/ldapuser02/file3
mkdir /home/guests/ldapuser02/{dir1,dir2,dir3}
chown -R ldapuser02:ldapuser02 /home/guests/ldapuser02

#####################
## End basic setup ##
#####################

#####################
## Begin NFS setup ##
#####################

yum -y install nfs-utils policycoreutils-python

## Create shared directory and add dummy files and dirs
mkdir /nfsshare
mkdir /nfsshare/{nfsdir1,nfsdir2,nfsdir3}
echo "NFSfile1 contents" > /nfsshare/nfsfile1
echo "NFSfile2 contents" > /nfsshare/nfsfile2
echo "NFSfile3 contents" > /nfsshare/nfsfile3
semanage fcontext -a -t public_content_rw_t "/nfsshare(/.*)?"
restorecon -Rv /nfsshare

setfacl -R -m d:u:ldapuser01:rwX /nfsshare
setfacl -R -m u:ldapuser01:rwX /nfsshare
setfacl -R -m d:u:ldapuser02:r-X /nfsshare
setfacl -R -m u:ldapuser02:r-X /nfsshare

echo "/home/guests     *.$LABDOMAIN(rw,sync,no_root_squash)" >> /etc/exports
echo "/nfsshare        *.$LABDOMAIN(rw,sync,no_root_squash)" >> /etc/exports

systemctl enable nfs-server rpcbind
systemctl start nfs-server rpcbind

exportfs -avr

firewall-cmd --permanent --add-service nfs --add-service rpc-bind --add-service mountd
firewall-cmd --reload

###################
## End NFS setup ##
###################

#########################
## Begin Postfix setup ##
#########################

yum -y install postfix

firewall-cmd --permanent --add-service smtp ; firewall-cmd --reload

systemctl enable postfix

mv /etc/postfix/main.cf /etc/postfix/main.cf.distrib
cat <<EOF > /etc/postfix/main.cf
queue_directory = /var/spool/postfix
command_directory = /usr/sbin
daemon_directory = /usr/libexec/postfix
data_directory = /var/lib/postfix
mail_owner = postfix
myhostname = $LABHOST.$LABDOMAIN
mydomain = $LABDOMAIN
myorigin = $LABDOMAIN
inet_interfaces = all
inet_protocols = all
mydestination = $LABHOST.$LABDOMAIN, localhost.$LABDOMAIN, localhost, $LABDOMAIN
unknown_local_recipient_reject_code = 550
mynetworks = 192.168.201.0/24, 127.0.0.0/8
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
debug_peer_level = 2
debugger_command =
         PATH=/bin:/usr/bin:/usr/local/bin:/usr/X11R6/bin
         ddd \$daemon_directory/\$process_name \$process_id & sleep 5
sendmail_path = /usr/sbin/sendmail.postfix
newaliases_path = /usr/bin/newaliases.postfix
mailq_path = /usr/bin/mailq.postfix
setgid_group = postdrop
html_directory = no
manpage_directory = /usr/share/man
sample_directory = /usr/share/doc/postfix-2.10.1/samples
readme_directory = /usr/share/doc/postfix-2.10.1/README_FILES
EOF

systemctl restart postfix

#######################
## End Postfix setup ##
#######################

############################
## Begin hypervisor setup ##
############################

yum -y groupinstall "Virtualization Hypervisor" "Virtualization Platform" \
"Virtualization Tools" "Virtualization Client"

systemctl enable libvirtd
systemctl start libvirtd

cat <<EOF > /tmp/virtnet1.xml
<network>
  <name>virtnet1</name>
  <uuid>e290a1b4-7ea8-4be6-b993-1cad7a432423</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr201' stp='on' delay='0'/>
  <mac address='52:54:00:58:3c:0c'/>
  <domain name='$LABDOMAIN'/>
  <ip address='192.168.201.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.201.10' end='192.168.201.99'/>
    </dhcp>
  </ip>
</network>
EOF

cat <<EOF > /tmp/virtnet2.xml
<network>
  <name>virtnet2</name>
  <uuid>a3b5faac-2138-4f7e-8379-17fe9b645037</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr202' stp='on' delay='0'/>
  <mac address='52:54:00:43:65:de'/>
  <domain name='$LABDOMAIN'/>
  <ip address='192.168.202.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.202.10' end='192.168.202.99'/>
    </dhcp>
  </ip>
</network>
EOF

virsh net-define /tmp/virtnet1.xml
virsh net-autostart virtnet1
virsh net-start virtnet1
rm -f /tmp/virtnet1.xml

virsh net-define /tmp/virtnet2.xml
virsh net-autostart virtnet2
virsh net-start virtnet2
rm -f /tmp/virtnet2.xml

virsh pool-define-as default dir - - - - "/var/lib/libvirt/images"
virsh pool-start default
virsh pool-autostart default

systemctl restart libvirtd

##########################
## End hypervisor setup ##
##########################

#######################
## Begin Samba setup ##
#######################

yum -y install samba samba-client cifs-utils

firewall-cmd --permanent --add-service samba ; firewall-cmd --reload

## Create shared directory and add dummy files and dirs
mkdir /cifsshare
mkdir /cifsshare/{cifsdir1,cifsdir2,cifsdir3}
echo "CIFSfile1 contents" > /cifsshare/cifsfile1
echo "CIFSfile2 contents" > /cifsshare/cifsfile2
echo "CIFSfile3 contents" > /cifsshare/cifsfile3
semanage fcontext -a -t samba_share_t "/cifsshare(/.*)?"
restorecon -Rv /cifsshare

setfacl -R -m d:u:ldapuser01:rwX /cifsshare
setfacl -R -m u:ldapuser01:rwX /cifsshare
setfacl -R -m d:u:ldapuser02:r-X /cifsshare
setfacl -R -m u:ldapuser02:r-X /cifsshare

mv /etc/samba/smb.conf /etc/samba/smb.conf.distrib
cat <<EOF > /etc/samba/smb.conf
[global]
  workgroup		= $SMBWKGP
  server string		= $LABHOST.$LABDOMAIN
  hosts allow		= 127. 192.168.201. .$LABDOMAIN
  interfaces		= lo virbr201 192.168.201.
  passdb backend	= smbpasswd
  security		= user
  log file		= /var/log/samba/%m.log
  max log size		= 5000
[cifsshare]
  comment		= /cifsshare directory
  browsable		= yes
  path			= /cifsshare
  public		= yes
  valid users		= ldapuser01,ldapuser02
  write list		= ldapuser01
  writable		= yes
EOF

(echo "$USERPASSWD" ; echo "$USERPASSWD") | smbpasswd -s -a ldapuser01
(echo "$USERPASSWD" ; echo "$USERPASSWD") | smbpasswd -s -a ldapuser02

systemctl enable smb
systemctl start smb

#####################
## End Samba setup ##
#####################

#######################
## Begin HTTPD setup ##
#######################

yum -y install httpd elinks

## Create a base repo location
## Copy the enterprise Linux installation media contents into this directory
mkdir -p /var/www/html/repo

## Create a kernel update repo location
mkdir -p /var/www/html/kernel/Packages
yum -y install wget createrepo
wget -O /var/www/html/kernel/Packages/kernel.rpm $KERNUPDURL
createrepo /var/www/html/kernel

## Create a distribution point for KRB5 keytabs
mkdir -p /var/www/html/krb #keytabs added later

## Create a distribution point for ldap SSL cert
mkdir -p /var/www/html/ldap #cert added later

## Create a distribution point for SSL certificates
mkdir -p /var/www/html/ssl

## Generate CA cert
openssl genrsa -passout pass:$CERTPASSWD -des3 -out /etc/pki/tls/private/ca.key 4096
chmod 600 /etc/pki/tls/private/ca.key
openssl req -new -x509 -days 365 -key /etc/pki/tls/private/ca.key -out /var/www/html/ssl/ca.crt \
-subj "/C=$CERTCNTRY/ST=$CERTSTATE/L=$CERTLOC/O=$CERTORG/OU=$CERTOU/CN=$CERTCN/emailAddress=$CERTEMAIL" \
-passin pass:$CERTPASSWD
chmod 644 /var/www/html/ssl/ca.crt

## Generate certificate and key for server1.example.com
openssl req -new -newkey rsa:2048 -nodes -keyout /var/www/html/ssl/server1.key.secure \
-out /var/www/html/ssl/server1.csr -passin pass:$CERTPASSWD \
-subj "/C=$CERTCNTRY/ST=$CERTSTATE/L=$CERTLOC/O=$CERTORG/OU=$CERTOU/CN=server1.$LABDOMAIN/emailAddress=$CERTEMAIL"
openssl x509 -req -days 365 -in /var/www/html/ssl/server1.csr -signkey /etc/pki/tls/private/ca.key \
-out /var/www/html/ssl/server1.crt -passin pass:$CERTPASSWD
chmod 644 /var/www/html/ssl/server1.crt
openssl rsa -in /var/www/html/ssl/server1.key.secure -out /var/www/html/ssl/server1.key \
-passin pass:$CERTPASSWD
chmod 644 /var/www/html/ssl/server1.key
rm -f /var/www/html/ssl/server1.csr
rm -f /var/www/html/ssl/server1.key.secure

## Provide access to the ldapuser01 and ldapuser02 mail spools
mkdir /var/www/html/mail
touch /var/www/html/mail/ldapuser01.txt
touch /var/www/html/mail/ldapuser02.txt

cat <<EOF > /usr/sbin/httpd-mailcopy.sh
#!/bin/bash
cp /var/spool/mail/ldapuser01 /var/www/html/mail/ldapuser01.txt
cp /var/spool/mail/ldapuser02 /var/www/html/mail/ldapuser02.txt
chown root:root /var/www/html/mail/*
chmod 644 /var/www/html/mail/* 
EOF

chmod 700 /usr/sbin/httpd-mailcopy.sh

echo "*/5 * * * * root /usr/sbin/httpd-mailcopy.sh" > /etc/cron.d/mailcopy

## Create a distribution point for kickstart files
mkdir -p /var/www/html/ks

## Create a distribution point for httpd templates
mkdir -p /var/www/html/httpd

## Create the main site template
cat <<EOF > /var/www/html/httpd/main.html
<html>
<head>
<title>Main Site</title>
</head>
<body>
<h1>Main Site</h1>
<p>This is the main site landing page.</p>
</body>
</html>
EOF

## Create the virtual site template
cat <<EOF > /var/www/html/httpd/virtual.html
<html>
<head>
<title>Virtual Site</title>
</head>
<body>
<h1>Virtual Site</h1>
<p>This is the virtual site landing page.</p>
</body>
</html>
EOF

## Create the restricted site template
cat <<EOF > /var/www/html/httpd/restricted.html
<html>
<head>
<title>Restricted Site</title>
</head>
<body>
<h1>Restricted Site</h1>
<p>This is the restricted site landing page.</p>
</body>
</html>
EOF

## Create the WSGI app template
cat <<EOF > /var/www/html/httpd/dynamic.wsgi
def application(environ, start_response):
    status = '200 OK'
    output = 'This is the WSGI dynamic content page. If you can read this, it works!'

    response_headers = [('Content-type', 'text/plain'),
                        ('Content-Length', str(len(output)))]
    start_response(status, response_headers)

    return [output]
EOF

## Create a distribution point for mariadb backup
mkdir -p /var/www/html/mariadb

## Create a sample database for importing/querying
cat <<EOF > /var/www/html/mariadb/backup.mdb
-- MySQL dump 10.14  Distrib 5.5.44-MariaDB, for Linux (x86_64)
--
-- Host: localhost    Database: AddressBook
-- ------------------------------------------------------
-- Server version	5.5.44-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table \`AB_entries\`
--

DROP TABLE IF EXISTS \`AB_entries\`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE \`AB_entries\` (
  \`EntryID\` int(11) DEFAULT NULL,
  \`FirstName\` varchar(255) DEFAULT NULL,
  \`LastName\` varchar(255) DEFAULT NULL,
  \`Email\` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table \`AB_entries\`
--

LOCK TABLES \`AB_entries\` WRITE;
/*!40000 ALTER TABLE \`AB_entries\` DISABLE KEYS */;
INSERT INTO \`AB_entries\` VALUES (1,'Albert','Apple','a.apple@$LABDOMAIN'),(2,'Bart','Banana','b.banana@$LABDOMAIN'),(3,'Paula','Pear','p.pear@$LABDOMAIN'),(4,'Otto','Orange','o.orange@$LABDOMAIN'),(5,'Georgina','Grape','g.grape@$LABDOMAIN');
/*!40000 ALTER TABLE \`AB_entries\` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2016-01-20 16:58:51
EOF

## Create resources index
cat <<EOF > /var/www/html/index.html
<html>
<head>
<title>Lab Details</title>
</head>
<body>
<h1>Lab Information</h1>
<p>The design of this lab environment assumes that you will run three VMs for lab
exercises. The VMs are assumed to have the following names, IP addresses, and functions:<br>
192.168.201.100 - server0.$LABDOMAIN - intended for level 1 labs<br>
192.168.201.101 - server1.$LABDOMAIN - intended for level 2 labs<br>
192.168.201.102 - server2.$LABDOMAIN - intended for level 2 labs</p>

<p>Two virtual networks are defined:<br>
virtnet1 - 192.168.201.0/24 - used for the VM primary network interfaces<br>
virtnet2 - 192.168.202.0/24 - used for exercises like network teaming and routing</p>

<p>DHCP is setup on both networks, issuing addresses from .10 to .99</p>

<p>Name service is provided to the virtual networks by dnsmasq, and hostnames have
been setup for the server0, server1, and server2 VM names.</p>

<p><strong>NOTE:</strong> No VMs have been automatically created. You may install VMs yourself
normally, or you may use the VM build scripts that are located in /root to build three pre-defined lab servers (see Lab Resources, below).</p>

<p>An LDAP directory has been created under the $LDAPPATH namespace.<br>
There are two LDAP user accounts:<br>
&nbsp;&nbsp;ldapuser01<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;password: $USERPASSWD<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;home dir: /home/guests/ldapuser01<br><br>

&nbsp;&nbsp;ldapuser02<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;password: $USERPASSWD<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;home dir: /home/guests/ldapuser01</p>

<p>A Kerberos KDC and realm for $KRB5REALM have been created.<br>
There are two Kerberos-enabled user accounts:<br>
&nbsp;&nbsp;ldapuser01<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;password: $USERPASSWD<br>
&nbsp;&nbsp;ldapuser02<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;password: $USERPASSWD</p>

<p>The following Kerberos server principals have also been created:</p>
<p>host/$LABHOST.$LABDOMAIN@$KRB5REALM<br>
host/server1.$LABDOMAIN@$KRB5REALM<br>
host/server2.$LABDOMAIN@$KRB5REALM<br>
nfs/server1.$LABDOMAIN@$KRB5REALM<br>
nfs/server2.$LABDOMAIN@$KRB5REALM</p>

<p>Keytabs for server1 and server2 are available (see Lab Resources below).</p>

<p>Local user accounts for ldapuser01 and ldapuser02 also exist. The password for these accounts
is '$USERPASSWD'.</p>

<p>NTP time service is installed on the lab host, and it is configured to allow time sync to the 
VMs on the defined virtual networks. Lab VMs should be configured to get their time from
$LABHOST.$LABDOMAIN [192.168.201.1] to ensure proper time sync (required for Kerberos).</p>

<p>NFS is configured to export two directories:<br>
/home/guests - used for LDAP+autofs labs<br>
/nfsshare    - a generic NFS share for testing non-krb5 NFS mounts</p>

<p>Both shares allow read/write access from hosts in $LABDOMAIN, but /nfsshare is read/write for
ldapuser01 and read-only for ldapuser02.</p>

<p>Samba is configured to share one directory at /cifsshare (share name [cifsshare]). This share
is also read/write for ldapuser01 and read-only for ldapuser02.</p>
<br><br>
<h1>Lab Resources</h1>
<p>The base repo is setup at: <a href="http://$LABHOST.$LABDOMAIN/repo/">http://$LABHOST.$LABDOMAIN/repo/</a><br>
You'll need to copy your installation media files to /var/www/html/repo for them to be available.</p>
<p>A kernel update repo is also available at: <a href="http://$LABHOST.$LABDOMAIN/kernel/">http://lab.example.com/kernel/</a><br>
This CentOS updated kernel RPM was downloaded for you as part of the setup script.</p>

<p>A distribution point for Kerberos keytab files is available at: <a href="http://$LABHOST.$LABDOMAIN/krb/">http://$LABHOST.$LABDOMAIN/krb/</a><br>
server1 keytab: <a href="http://$LABHOST.$LABDOMAIN/krb/server1.keytab">http://$LABHOST.$LABDOMAIN/krb/server1.keytab</a><br>
server2 keytab: <a href="http://$LABHOST.$LABDOMAIN/krb/server2.keytab">http://$LABHOST.$LABDOMAIN/krb/server2.keytab</a></p>

<p>A krb5.conf file for server1 and server 2 is also available at: <a href="http://$LABHOST.$LABDOMAIN/krb/krb5.conf">http://$LABHOST.$LABDOMAIN/krb/krb5.conf</a></p>

<p>For LDAP authentication labs, a LDAPS cert is available here: <a href="http://$LABHOST.$LABDOMAIN/ldap/cert.pem">http://$LABHOST.$LABDOMAIN/ldap/cert.pem</a></p>

<p>Mail spools for the ldapuser01 and ldapuser02 can be viewed here:<br>
ldapuser01: <a href="http://$LABHOST.$LABDOMAIN/mail/ldapuser01.txt">http://$LABHOST.$LABDOMAIN/mail/ldapuser01.txt</a><br>
ldapuser02: <a href="http://$LABHOST.$LABDOMAIN/mail/ldapuser02.txt">http://$LABHOST.$LABDOMAIN/mail/ldapuser02.txt</a></p>
<p>Replication of the spool files occurs every 5 minutes, so there may be some delay between sending an email and seeing it in the spool file.</p>

<p>SSL certificatess for Apache labs are available at: <a href="http://$LABHOST.$LABDOMAIN/ssl/">http://$LABHOST.$LABDOMAIN/ssl/</a><br>
CA cert: <a href="http://$LABHOST.$LABDOMAIN/ssl/ca.crt">http://$LABHOST.$LABDOMAIN/ssl/ca.crt</a><br>
server1 cert: <a href="http://$LABHOST.$LABDOMAIN/ssl/server1.crt">http://$LABHOST.$LABDOMAIN/ssl/server1.crt</a><br>
server1 key: <a href="http://$LABHOST.$LABDOMAIN/ssl/server1.key">http://$LABHOST.$LABDOMAIN/ssl/server1.key</a></p>

<p>HTML page templates for HTTPD labs are available here:<br>
Main site: <a href="http://$LABHOST.$LABDOMAIN/httpd/main.html">http://$LABHOST.$LABDOMAIN/httpd/main.html</a><br>
Virtual site: <a href="http://$LABHOST.$LABDOMAIN/httpd/virtual.html">http://$LABHOST.$LABDOMAIN/httpd/virtual.html</a><br>
Restricted site: <a href="http://$LABHOST.$LABDOMAIN/httpd/restricted.html">http://$LABHOST.$LABDOMAIN/httpd/restricted.html</a><br>
Sample WSGI app: <a href="http://$LABHOST.$LABDOMAIN/httpd/dynamic.wsgi">http://$LABHOST.$LABDOMAIN/httpd/dynamic.wsgi</a></p>

<p>A sample MariaDB database (named AddressBook) for backup/restore labs is available at: <a href="http://$LABHOST.$LABDOMAIN/mariadb/backup.mdb">http://$LABHOST.$LABDOMAIN/mariadb/backup.mdb</a></p>

<p>Kickstart scripts are provided for automated install of the lab VMs:<br>
server0:  <a href="http://$LABHOST.$LABDOMAIN/ks/server0-ks.cfg">http://$LABHOST.$LABDOMAIN/ks/server0-ks.cfg</a><br>
server1:  <a href="http://$LABHOST.$LABDOMAIN/ks/server1-ks.cfg">http://$LABHOST.$LABDOMAIN/ks/server1-ks.cfg</a><br>
server2:  <a href="http://$LABHOST.$LABDOMAIN/ks/server2-ks.cfg">http://$LABHOST.$LABDOMAIN/ks/server2-ks.cfg</a></p>

<p>VM build scripts are located in the /root directory to automate VM creation:<br>
/root/mkserver0.sh<br>
/root/mkserver1.sh<br>
/root/mkserver2.sh</p>

<p><strong>IMPORTANT:</strong> In order to use the provided build scripts, you must first copy your enterprise Linux installation media into the /var/www/html/repo directory.</p>

</body>
</html>
EOF

## Create the HTTPD config
cat <<EOF > /etc/httpd/conf.d/lab.conf
<VirtualHost *:80>
     ServerAdmin webmaster@$LABHOST.$LABDOMAIN
     ServerName $LABHOST.$LABDOMAIN
     DocumentRoot "/var/www/html"
     ErrorLog "logs/error_log_$LABHOST"
     CustomLog "logs/access_log_$LABHOST" combined
</VirtualHost>
<Directory "/var/www/html">
     Options Indexes FollowSymLinks
     AllowOverride None
     Require all granted
</Directory>
EOF

systemctl enable httpd
systemctl start httpd

firewall-cmd --permanent --add-service http ; firewall-cmd --reload 

#####################
## End HTTPD setup ##
#####################

#####################
## Begin KDC setup ##
#####################

yum -y install krb5-server krb5-workstation pam_krb5 chrony

## Setup time services
echo "allow 192.168/16" >> /etc/chrony.conf
systemctl enable chronyd
systemctl start chronyd
firewall-cmd --permanent --add-service ntp ; firewall-cmd --reload

## Create a krb5.conf file
mv /etc/krb5.conf /etc/krb5.conf.distrib
touch /etc/krb5.conf
chown root:root /etc/krb5.conf
chmod 644 /etc/krb5.conf
cat <<EOF > /etc/krb5.conf
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = $KRB5REALM
 default_ccache_name = KEYRING:persistent:%{uid}

[realms]
 $KRB5REALM = {
  kdc = $LABHOST.$LABDOMAIN
  admin_server = $LABHOST.$LABDOMAIN
 }

[domain_realm]
 .$LABDOMAIN = $KRB5REALM
 $LABDOMAIN = $KRB5REALM
EOF

## Copy the krb5.conf file to the krb distribution point for server1 and server2
cp /etc/krb5.conf /var/www/html/krb/

## Create a kdc.conf file
mv /var/kerberos/krb5kdc/kdc.conf /var/kerberos/krb5kdc/kdc.conf.distrib
touch /var/kerberos/krb5kdc/kdc.conf
chown root:root /var/kerberos/krb5kdc/kdc.conf
chmod 600 /var/kerberos/krb5kdc/kdc.conf
cat <<EOF > /var/kerberos/krb5kdc/kdc.conf
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 $KRB5REALM = {
  #master_key_type = aes256-cts
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
  supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal camellia256-cts:normal camellia128-cts:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
 }
EOF

## Create a kadm5.acl file
mv /var/kerberos/krb5kdc/kadm5.acl /var/kerberos/krb5kdc/kadm5.acl.distrib
touch /var/kerberos/krb5kdc/kadm5.acl
chown root:root /var/kerberos/krb5kdc/kadm5.acl
chmod 600 /var/kerberos/krb5kdc/kadm5.acl
echo "*/admin@$KRB5REALM        *" > /var/kerberos/krb5kdc/kadm5.acl

## Create Kerberos realm
 
kdb5_util create -s -r $KRB5REALM -P $KRB5PASSWD -W
systemctl enable krb5kdc kadmin
systemctl start krb5kdc kadmin

## Create user principals
kadmin.local -q "addprinc -pw $ADMNPASSWD root/admin"
kadmin.local -q "addprinc -pw $USERPASSWD ldapuser01"
kadmin.local -q "addprinc -pw $USERPASSWD ldapuser02"

## Create KDC principals
kadmin.local -q "addprinc -randkey host/$LABHOST.$LABDOMAIN"
kadmin.local -q "ktadd host/$LABHOST.$LABDOMAIN"

## Create server principals (for RHCE labs)
kadmin.local -q "addprinc -randkey host/server1.$LABDOMAIN"
kadmin.local -q "addprinc -randkey host/server2.$LABDOMAIN"
kadmin.local -q "addprinc -randkey nfs/server1.$LABDOMAIN"
kadmin.local -q "addprinc -randkey nfs/server2.$LABDOMAIN"
kadmin.local -q "ktadd -k /var/www/html/krb/server1.keytab host/server1.$LABDOMAIN"
kadmin.local -q "ktadd -k /var/www/html/krb/server1.keytab nfs/server1.$LABDOMAIN"
kadmin.local -q "ktadd -k /var/www/html/krb/server2.keytab host/server2.$LABDOMAIN"
kadmin.local -q "ktadd -k /var/www/html/krb/server2.keytab nfs/server2.$LABDOMAIN"
chmod 644 /var/www/html/krb/*.keytab

## Allow SSH login with Kerberos
cat <<EOF >> /etc/ssh/ssh_config
Host *.$LABDOMAIN
  GSSAPIAuthentication yes
  GSSAPIDelegateCredentials yes
EOF

systemctl restart sshd

## Enable PAM authentication with Kerberos
authconfig --enablekrb5 --update

## Add firewall rules for kerberos
cat <<EOF > /etc/firewalld/services/kerberos.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Kerberos</short>
  <description>Kerberos authentication</description>
  <port protocol="tcp" port="749"/>
  <port protocol="tcp" port="88"/>
  <port protocol="udp" port="88"/>
</service>
EOF

firewall-cmd --permanent --add-service=kerberos ; firewall-cmd --reload

###################
## End KDC setup ##
###################

######################
## Begin LDAP setup ##
######################

yum install -y openldap openldap-clients openldap-servers migrationtools
slappasswd -s $LDAPPASSWD -n > /etc/openldap/passwd

firewall-cmd --permanent --add-service=ldap ; firewall-cmd --reload

## Generate LDAP certificate
openssl req -new -x509 -nodes -out /etc/openldap/certs/cert.pem \
-keyout /etc/openldap/certs/priv.pem -days 365 \
-subj "/C=$CERTCNTRY/ST=$CERTSTATE/L=$CERTLOC/O=$CERTORG/OU=$CERTOU/CN=$CERTCN/emailAddress=$CERTEMAIL"

chown ldap:ldap /etc/openldap/certs/*
chmod 600 /etc/openldap/certs/priv.pem
cp /etc/openldap/certs/cert.pem /var/www/html/ldap
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG

## Generate the LDAP database
slaptest
chown ldap:ldap /var/lib/ldap/*

systemctl enable slapd
systemctl start slapd

## Create LDIFs

cat <<EOF > /etc/openldap/changes.ldif
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: $LDAPPATH

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=Manager,$LDAPPATH

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $(cat /etc/openldap/passwd)

dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/cert.pem

dn: cn=config
changetype: modify
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/priv.pem

dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: -1

dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by dn.base="cn=Manager,$LDAPPATH" read by * none
EOF

chmod 600 /etc/openldap/changes.ldif

cat <<EOF > /etc/openldap/base.ldif
dn: $LDAPPATH
dc: $LDAPBASE
objectClass: top
objectClass: domain

dn: ou=People,$LDAPPATH
ou: People
objectClass: top
objectClass: organizationalUnit

dn: ou=Group,$LDAPPATH
ou: Group
objectClass: top
objectClass: organizationalUnit
EOF

## Add schemas
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f /etc/openldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -D "cn=config" -f /etc/openldap/schema/nis.ldif
ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/openldap/changes.ldif
ldapadd -x -w $LDAPPASSWD -D cn=Manager,$LDAPPATH -f /etc/openldap/base.ldif

## Migrate ldapuser01 and ldapuser02 into LDAP
cp /usr/share/migrationtools/migrate_common.ph /usr/share/migrationtools/migrate_common.ph.distrib
sed "s/padl.com/$LABDOMAIN/g" /usr/share/migrationtools/migrate_common.ph.distrib > /tmp/migrate_common.ph.tmp
sed "s/dc=padl,dc=com/$LDAPPATH/g" /tmp/migrate_common.ph.tmp > /usr/share/migrationtools/migrate_common.ph
rm -f /tmp/migrate_common.ph.tmp

grep ":20[0-9][0-9]" /etc/passwd > /tmp/passwd
/usr/share/migrationtools/migrate_passwd.pl /tmp/passwd /etc/openldap/users.ldif
rm -f /tmp/passwd

grep ":20[0-9][0-9]" /etc/group > /tmp/group
/usr/share/migrationtools/migrate_group.pl /tmp/group /etc/openldap/groups.ldif
rm -f /tmp/group

ldapadd -x -w $LDAPPASSWD -D cn=Manager,$LDAPPATH -f /etc/openldap/users.ldif
ldapadd -x -w $LDAPPASSWD -D cn=Manager,$LDAPPATH -f /etc/openldap/groups.ldif

## Enable LDAP logging via syslog

echo "local4.* /var/log/ldap.log" >> /etc/rsyslog.conf
systemctl restart rsyslog


####################
## End LDAP setup ##
####################

###########################
## Begin kickstart files ##
###########################

## Kickstart file for server0
cat <<EOF > /var/www/html/ks/server0-ks.cfg
#version=DEVEL
# System authorization information
url --url="http://$LABHOST.$LABDOMAIN/repo"
lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts='us'
network  --bootproto=dhcp --device=eth0 --onboot=on --ipv6=auto
network  --hostname=localhost.localdomain
rootpw $VMROOTPASS
user --name=user1 --password=$USERPASSWD --shell=/bin/bash --uid=4000
auth --enableshadow --passalgo=sha512
reboot
timezone America/New_York --isUtc
firstboot --disable
eula --agreed
selinux --permissive
ignoredisk --only-use=vda
zerombr
clearpart --all --initlabel --drives=vda
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=vda
part /boot --fstype="xfs" --ondisk=vda --size=500 --label=boot
part pv.155 --fstype="lvmpv" --ondisk=vda --size=12775
volgroup vg00 --pesize=4096 pv.155
logvol /  --fstype="xfs" --size=10720 --label="root" --name=root --vgname=vg00
logvol swap  --fstype="swap" --size=2047 --name=swap --vgname=vg00
text

%packages
@base
@core
@desktop-debugging
@dial-up
@fonts
@gnome-desktop
@input-methods
@internet-browser
@print-client
@x11
kexec-tools

%end
EOF

## Kickstart file for server1
cat <<EOF > /var/www/html/ks/server1-ks.cfg
#version=DEVEL
# System authorization information
url --url="http://$LABHOST.$LABDOMAIN/repo"
lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts='us'
network  --bootproto=static --device=eth0 --ip=192.168.201.101 --netmask=255.255.255.0 --gateway=192.168.201.1 --onboot=on --ipv6=auto
network  --hostname=server1.$LABDOMAIN
rootpw $VMROOTPASS
user --name=user1 --password=$USERPASSWD --shell=/bin/bash --uid=4000
auth --enableshadow --passalgo=sha512
reboot
timezone America/New_York --isUtc
firstboot --disable
eula --agreed
selinux --permissive
ignoredisk --only-use=vda
zerombr
clearpart --all --initlabel --drives=vda
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=vda
part /boot --fstype="xfs" --ondisk=vda --size=500 --label=boot
part pv.155 --fstype="lvmpv" --ondisk=vda --size=12775
volgroup vg00 --pesize=4096 pv.155
logvol /  --fstype="xfs" --size=10720 --label="root" --name=root --vgname=vg00
logvol swap  --fstype="swap" --size=2047 --name=swap --vgname=vg00
text

%packages
@base
@core
@desktop-debugging
@dial-up
@fonts
@gnome-desktop
@input-methods
@internet-browser
@print-client
@x11
kexec-tools
krb5-workstation
pam_krb5

%end
EOF

## Kickstart file for server2
cat <<EOF > /var/www/html/ks/server2-ks.cfg
#version=DEVEL
# System authorization information
url --url="http://$LABHOST.$LABDOMAIN/repo"
lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts='us'
network  --bootproto=static --device=eth0 --ip=192.168.201.102 --netmask=255.255.255.0 --gateway=192.168.201.1 --onboot=on --ipv6=auto
network  --hostname=server2.$LABDOMAIN
rootpw $VMROOTPASS
user --name=user1 --password=$USERPASSWD --shell=/bin/bash --uid=4000
auth --enableshadow --passalgo=sha512
reboot
timezone America/New_York --isUtc
firstboot --disable
eula --agreed
selinux --permissive
ignoredisk --only-use=vda
zerombr
clearpart --all --initlabel --drives=vda
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=vda
part /boot --fstype="xfs" --ondisk=vda --size=500 --label=boot
part pv.155 --fstype="lvmpv" --ondisk=vda --size=12775
volgroup vg00 --pesize=4096 pv.155
logvol /  --fstype="xfs" --size=10720 --label="root" --name=root --vgname=vg00
logvol swap  --fstype="swap" --size=2047 --name=swap --vgname=vg00
text

%packages
@base
@core
@desktop-debugging
@dial-up
@fonts
@gnome-desktop
@input-methods
@internet-browser
@print-client
@x11
kexec-tools
krb5-workstation
pam_krb5

%end
EOF

#########################
## End kickstart files ##
#########################

############################
## Begin VM build scripts ##
############################

cat <<EOF > /root/mkserver0.sh
virsh vol-create-as default server0.qcow2 20G --format qcow2
virt-install --name=server0 \
  --ram=1024 \
  --vcpu=1 \
  --autostart \
  --os-type=linux \
  --os-variant=rhel7 \
  --location=http://$LABHOST.$LABDOMAIN/repo/ \
  --disk vol=default/server0.qcow2 \
  --network network=virtnet1 \
  --extra-args ks=http://$LABHOST.$LABDOMAIN/ks/server0-ks.cfg
EOF
chmod 700 /root/mkserver0.sh

cat <<EOF > /root/mkserver1.sh
virsh vol-create-as default server1.qcow2 20G --format qcow2
virt-install --name=server1 \
  --ram=1024 \
  --vcpu=1 \
  --autostart \
  --os-type=linux \
  --os-variant=rhel7 \
  --location=http://$LABHOST.$LABDOMAIN/repo/ \
  --disk vol=default/server1.qcow2 \
  --network network=virtnet1 \
  --network network=virtnet2 \
  --network network=virtnet2 \
  --extra-args ks=http://$LABHOST.$LABDOMAIN/ks/server1-ks.cfg
EOF
chmod 700 /root/mkserver1.sh

cat <<EOF > /root/mkserver2.sh
virsh vol-create-as default server2.qcow2 20G --format qcow2
virt-install --name=server2 \
  --ram=1024 \
  --vcpu=1 \
  --autostart \
  --os-type=linux \
  --os-variant=rhel7 \
  --location=http://$LABHOST.$LABDOMAIN/repo/ \
  --disk vol=default/server2.qcow2 \
  --network network=virtnet1 \
  --network network=virtnet2 \
  --network network=virtnet2 \
  --extra-args ks=http://$LABHOST.$LABDOMAIN/ks/server2-ks.cfg
EOF
chmod 700 /root/mkserver2.sh

##########################
## End VM build scripts ##
##########################

## All done
clear
echo ""
echo "ELLIS: Enterprise Linux Lab Installer Script ver. $ELLISVER"
echo ""
echo "Lab server setup is complete."
echo ""
echo "Press any key to continue..."
read -n 1 -s

elinks http://$LABHOST.$LABDOMAIN


