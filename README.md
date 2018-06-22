# ELLIS
#### Enterprise Linux Lab Installer Script

## General purpose

This is a script to quickly and easily setup a pre-configured lab
environment useful for studying to obtain enterprise Linux certifications.

This script is intended to be run on a clean, updated installation of [CentOS](http://centos.org/).
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

## Requirements

You will need a computer to act as the lab host. This system will run CentOS and should
have reasonable hardware for a VM host. The recommended minimum specifications for the lab
host are:

- Core i5 processor or better, with Intel-VT support
- 6GB+ of memory
- 80GB+ of disk space

**NOTE**: memory requirements have increased for RHEL7.5/CentOS7.5 from earlier versions. The lab VMs
are now pre-configured for 2GB of memory instead of the previous 1GB setting. Using less than
1.5GB, the installer will crash during kickstart. If you need to run more than one VM at a time,
you'll want to have 6GB or more of physical memory in your lab server.

This installer has now been tested with the following version of CentOS:

- 7.5 (1804)

Running the script on other versions of CentOS is not recommended, but can be done by uncommenting
the following line:

    #CHECKVER=false

You will also require an installation image for the enterprise Linux OS of your choice
(either [CentOS](https://www.centos.org/download/) or [RHEL](https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux)) 
in order to build your local repository for use in the installation of your lab VMs.

## Setup and Installation

The setup process is pretty simple:
 
1. Perform a clean install of CentOS on your lab host/station, either as a 
"Minimal Install" (for a headless lab server) or "Server with GUI" (if you intend to 
use the lab server as your lab station). **NOTE:** Do not provision a separate /home 
partition. You will need the majority of your disk space to be available under 
`/var/lib/libvirt` (for your VM disks).

2. Update the CentOS install via `yum -y update`. Reboot if necessary.
 
3. Log into your lab server (as root) and copy the `ellis.sh` script to your server (under 
/root or elsewhere).

    You can clone this repo:
    
        yum -y install git
        git clone https://github.com/sdoconnell/ellis.git && cd ellis
        chmod 755 ellis.sh
    
    Or you can download the repo [zip file](https://github.com/sdoconnell/ELLIS/archive/master.zip) and extract it.
    
    Or you can download the `ellis.sh` script directly, using curl:
    
        curl -o ellis.sh https://raw.githubusercontent.com/sdoconnell/ellis/master/ellis.sh && chmod 755 ellis.sh
    
4. Once the script is installed on your lab server, run `./ellis.sh`. ELLIS will download and
install all of the required packages from the standard CentOS repos and configure everything
automatically. The process should take five to ten minutes, depending on your Internet speed
and lab server hardware resources.
 
5. Copy all of the files from your enterprise Linux installation media (either CentOS 7.5 or RHEL 7.5)
into the /var/www/html/repo directory on the lab server. For example, to copy the files from an ISO image:

        mkdir -p /mnt/centos
        mount CentOS-7-x86_64-DVD-1804.iso /mnt/centos
        rsync -a /mnt/centos/ /var/www/html/repo/
        umount /mnt/centos

5. Run the provided build scripts placed in /root to setup your lab VMs *(optional)*.

        cd /root
        ./mkserver0.sh
        ./mkserver1.sh
        ./mkserver2.sh

## Lab resources

This script installs a web server on the lab host and makes a number of useful lab
resources available. Links to these resources and documentation about the configured
network services can be found by browsing to your lab server's default web site,
(ex. http://lab.example.com/).

