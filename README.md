#ELLIS
####Enterprise Linux Lab Installer Script for CentOS 7.2

##General purpose

This is a script to quickly and easily setup a pre-configured lab
environment useful for studying to obtain enterprise Linux certifications.

This script is intended to be run on a clean, updated installation of CentOS 7.2.
It is presumed that you have configured networking during the install, and that the
host machine has access to the Internet.

The script will install and configure the following lab components on the target host:

- A virtualization host and two virtual networks with DHCP and name services
- A kerberos realm with user and server principals, and necessary server keytab files
- An LDAP domain with pre-configured users
- An NFS server with home directory and generic shares
- A Samba server with a generic share
- An HTTP server with repo locations and lab resource files
- Kickstart files for lab VMs and automated VM build scripts
- An NTP server for time synchronization and lab use
- A Postfix SMTP host with delivery for the lab domain (for relay labs)

By default, ELLIS sets up all of the services under the generic namespace of example.com.
If you wish to use a different name space, edit the variables at the top of the script
before you run ELLIS.

##Requirements

You will need a computer to act as the lab host. This system will run CentOS 7.2 and should
have reasonable hardware for a VM host. The recommended minimum specifications for the lab
host are:

- Core i5 processor or better, with Intel-VT support
- 4GB+ of memory
- 80GB+ of disk space

You will also require an installation image for the enterprise Linux OS of your choice
(either CentOS 7 or RHEL 7) in order to build your local repository and to use in order
to install your lab VMs.

##Setup

The setup process is pretty simple:
 
1. Perform a clean install of CentOS 7.2 on your lab host/station, either as a 
"Minimal Install" (for a headless lab server) or "Server with GUI" (if you intend to 
use the lab server as your lab station). **NOTE:** Do not provision a separate /home 
partition. You will need the majority of your disk space to be available under 
/var/lib/libvirt (for your VM disks).

2. Update the CentOS 7.2 install via `yum -y update`. Reboot if necessary.
 
3. Log into your lab server (as root) and copy the `ellis.sh` script to your server (under 
/root or elsewhere).

4. Run `./ellis.sh`. ELLIS will download and install all of the required packages from 
the standard CentOS repos and configure everything automatically. The process should 
take five to ten minutes, depending on your Internet speed.
 
5. Copy all of the files from your enterprise Linux installation media (either CentOS 7 or RHEL 7)
into the /var/www/html/repo directory.

5. Run the provided build scripts placed in /root to setup your lab VMs *(optional)*.

##Lab resources

This script installs a web server on the lab host and makes a number of useful lab
resources available. Links to these resources and documentation about the configured
network services can be found by browsing to your lab server's default web site,
(ex. http://lab.example.com/).

