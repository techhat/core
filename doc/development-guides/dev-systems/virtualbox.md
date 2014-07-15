### VirtualBox Development System ###

To set up a VirtualBox environment for Crowbar Development, follow these given instructions.


VirtualBox

1. File...Preferences...Network
  1. you want at least two Host-Only Ethernet Adapters
  * #1 should be IP 192.168.222.1 & DHCP should be off
  * #2 should be IP 192.168.124.1 & DHCP should be off
* Create new Linux Ubuntu 64 bit Virtual Machine
  1. RAM: 4096
  * Disk: VDI, Dynamically Allocated, at least 40 GB (80 recommended)
* Before Booting, go into settings
  1. System...Processor: give your self at least 2 cores
  * Storage IDE Controller; choose CD Ubuntu-12.04.4-server-amd64.iso
    * you have to download the ISO but you'll need it later
  * Network:
    * Adapter 1 (default OK) - NAT
    * Adapter 2 - Host Only #1 (has no number)
    * Adapter 3 - Host Only #2
* Start the server and answer the prompts
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
  1. `sudo vi /etc/network/interfaces`
  * add the following lines
    * `auto eth1`
    * `iface eth1 inet static`
    * `  address 192.168.222.6`
    * `  netmask 255.255.255.0`

  * `sudo service networking restart`

  * validate network by using Putty to SSH into crowbar@192.168.222.6
