# Dev System Configuration

Engineers value documentation that explains how to get a development workstation configured quickly. It is human nature to customize and change things - we do this frequently, but sometimes we need to get back to first base.  This document will help to get you there.

##Installation and Configuration Information

> An attempt has been made to pre-stage downloads so several steps can be done in parallel.  The docker image pull also has a large download it's OK to read ahead and start that too.

###Base OS Installed

  Go to [This tutorial](virtualbox.md), if you are setting Crowbar up with VirtualBox.

  1. Setup an .ssh keypair
    1. use `ssh-keygen -t rsa`
    2. if that fails, try `rssh-keygen`
  1. Passwordless sudo: `sudo sed -ie "s/%sudo\tALL=(ALL:ALL) ALL/%sudo ALL=(ALL) NOPASSWD: ALL/g" /etc/sudoers`
    1. additional information, see http://serverfault.com/questions/160581/how-to-setup-passwordless-sudo-on-linux
  1. Optional, [SAMBA and CNTLM](samba_cntlm.md) if you are developing on Windows using VMs and/or behind corporate firewalls
  1. Setup a [Squid Proxy](proxy-cache.md) to ensure downloads are fast (needed by Crowbar too)
  1. Make sure your environment does not use proxy for local addresses: 
    1. `export no_proxy="127.0.0.1,[::1],localhost,192.168.124.0/24,172.16.0.0/12"`
    1. tip: add this to your login init
  1. you need git and tmux: `sudo apt-get install git tmux`

###Position Boot Assets
  
> We'll need this for later but it takes a while so we do it now in different window....

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
  1. if you want to contribute
    1. review [Contribute Guidelines](../contributing-code.md)
    2. setup your [personal git fork](../contributing.md)
  1. Advanced user optional [build Sledgehammer](build_sledgehammer)

###Setup Docker Admin Node 
  1. follow steps in [docker-admin.md](docker-admin.md)

###Deploy Nodes!  

Now that you've got Crowbar installed, it's time to look in the [Deployment Guide](../../deployment-guide/README.md) for instructions about provisioning nodes.

###Change to Crowbar user
  1. `su - crowbar` to gain ruby-2.0 and control Crowbar via the CLI!
  1. we've provided a handle `tools/rails-console` command if you want to reach deep into the bowels of the bunny.


