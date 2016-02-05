#ELLIS
####Enterprise Linux Lab Installer Script for CentOS 7.2
####Version 0.1 rev. 2016-02-05 

##General purpose

The purpose of this script is to quickly and easily setup a pre-configured lab
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

##Setup

The setup process is pretty simple:
 
1. Install a clean CentOS 7.2 image on your lab host/station, either as a "Minimal Install"
(for a headless lab server) or "Server with GUI" (if you intend to use the lab server as
your lab station).

2. Update the CentOS 7.2 install via `yum -y update`.
 
3. Run ELLIS (`./ellis.sh`). ELLIS will download and install all of the necessary packages
from the standard CentOS repos, and configure everything automatically. The process should
take five to ten minutes, depending upon your Internet speed.
 
4. Copy your enterprise Linux installation media (either CentOS 7 or RHEL 7) into the
/var/www/html/repo directory.

5. Run the provided build scripts to setup VMs (optional).

##Lab resources

This script installs a web server on the lab host and makes a number of useful lab
resources available. Links to these resources and documentation about the configured
network services can be found by browsing to your lab server's default web site,
(ex. http://lab.example.com/).

