# Configuration Guide - Ubuntu 12.04.03


* Start the Ubuntu server install and answer the prompts
  * English & Ubuntu Server
    * Choose eth0 as your primary interface
  * Name your machine and user accounts (we recommend "crowbar" as user) & time zone
  * Partitioning: guided to use entire disk and LVM
    * defaults are OK
    * you need to select YES to continue (NO = return to selection)
  * Proxy depends on your environment (we'll install Squid later)
    1. No automatic updates
  * Install OpenSSH & Samba (space toggles, enter continues)
  * Install GRUB boot loader
* When Installation completes, make sure the ISO is not attached and allow reboot
* you may want to snapshot the machine in this state
 
* Add Network for SSH from Host
`sudo vi /etc/network/interfaces` and add the following lines

```
auto eth1
iface eth1 inet static
  address 192.168.222.6
  netmask 255.255.255.0
```
then restart networking:
`sudo service networking restart`

* validate network access to this net network by using Putty (or other ssh client) to SSH into crowbar@192.168.222.6

* Add git so you can clone your the OpenCrowbar/core repo:
 
`apt-get install git`

* Add what ever other development tools you like.  This will be your development environment.


