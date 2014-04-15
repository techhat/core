# Dev System Configuration

Engineers value documentation that explains how to get a development workstation configured quickly. It is human nature to customize and change things - we do this frequently, but sometimes we need to get back to first base.  This document will help to get you there.

##Installation and Configuration Information

> An attempt has been made to pre-stage downloads so several steps can be done in parallel.  The docker image pull also has a large download it's OK to read ahead and start that too.

###Base OS Installed
  1. VirtualBox, THREE network interfaces
    1. (assumed to be eth0) bridge external 
    1. (assumed to be eth1) on a host-only network - you need to setup to talk to the VM, we don't use it.
    1. (assumed to be eth2) on a host-only network - *NO IP assignment* or OS interface configuration (`/etc/network/interfaces` or `/etc/sysconfig`). If using Docker, setup bridging as in [docker-admin.md](docker-admin.md)
  1. Setup an .ssh keypair using `rssh-keygen`
  1. Optional Items that we find handy if you are developing on Windows using VMs behind corporate firewalls
    1. CNTLM proxy: 
      1. ubuntu: `sudo apt-get install cntlm`
      1. make sure that you allow NON local hosts to use the proxy (in `/etc/cntlm.conf` set `gateway yes`)!  Containers are not "local" and require your CNTLM proxy to act as a gateway.
    1. Setup a [Squid Proxy](proxy-cache.md)
    1. SAMBA share
      1. ubuntu: `sudo apt-get install samba`
  1. Make sure you setup noproxy for your environment: `export no_proxy="127.0.0.1,[::1],localhost,192.168.124.0/24,172.16.0.0/12"
    1. tip: add this to your login init
  1. Passwordless sudo: `sudo sed -ie "s/%sudo\tALL=(ALL:ALL) ALL/%sudo ALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers`
    1. additional information, see http://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux
  1. if you are stuck behind a proxy, make sure your environment does not use it for local addresses: `export no_proxy="127.0.0.1,[::1],localhost,192.168.124.0/24,172.16.0.0/12"`
  1. `apt-get install git`

###Position Boot Assets
  
> We'll need this for later but it takes a while so we do it now....

Copy the ISOs that you want for nodes to `$HOME/.cache/opencrowbar/tftpboot/isos`.  It's OK to have more than 1 but make sure you have the space!

Examples:
  1. `mkdir -p $HOME/.cache/opencrowbar/tftpboot/isos`
  1. `cd $HOME/.cache/opencrowbar/tftpboot/isos`
  1. Centos: `wget http://centos.mirror.ndchost.com/6.5/isos/x86_64/CentOS-6.5-x86_64-bin-DVD1.iso`
  1. Ubuntu: `wget http://releases.ubuntu.com/12.04.4/ubuntu-12.04.4-server-amd64.iso`

###Checkout Code 
  1. get git
    1. ubuntu: `sudo apt-get install git`
  1. get the code: `git clone https://github.com/opencrowbar/core`

If you want to **commit code or docs fixes**, please review [the Contributor guide](../contributing.md)

###Build Sledgehammer (Optional - setup will now download golden sledgehammers.)
  1. prep for sledgehammer requirements: 
    1. ubuntu: `sudo apt-get install rpm rpm2cpio`
  1. from core, `tools/build_sledgehammer.sh`
    1. warning: this may take multiple attempts to complete to downloads.  Keep trying.
    2. warning: might need a better literal mirror in sledgehammer/sledgehammer.ks - see [Details]((../../workflow/dev-build-sledgehammer.md))

###Setup Docker Admin Node 
  1. follow steps in [docker-admin.md](docker-admin.md)

###Change to Crowbar user
  1. `su - crowbar` to gain ruby-2.0 and control Crowbar!
