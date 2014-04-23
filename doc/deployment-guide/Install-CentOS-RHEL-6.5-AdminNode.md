# RHEL/CentOS 6.5 Deployment Guide

##Objectives

Create an OpenCrowbar admin node on a VM or physical machine to begin the process of configuring or managing deployment of a cluster (openstack, hadoop, ceph, etc.).

The following steps will be completed:

    * Prepare a Virtual or Physical machine
    * Installation of CentOS 6.5 x86_64
    * Install OpenCrowbar
    * Start OpenCrowbar webUI
    * Connect to the webUI using a browser

An outline is provided as a foundation for QA validation requirements for OpenCrowbar RPM packages.

Known limitations of the installation process, its sensitivities to updates and to upgrades is summarized.
Installation process:

Before commencing installation and configuration processing ensure that everything needed is available and that all remote resources that must be accessed are capable of being reached.

##Pre-Requisites:
   
   * CentOS 6.5 x86_64 - download site: http://www.centos.org/download/ 
   * You will need to know how to access the internet from your VM/Physical environment.  
   * Proxy Services
       * Windows - Fiddler 2 is a good one
       * Linux - potential proxy services include: cntlm and squid.
       * Direct Connection - Ensure you have appropriate security setup per security guidelines in effect within your organization.

## Machine preparation

Machine requirements are:

    * Memory: Min 4GB
    * CPU Cores: 2 or more
    * Network Interface Controllers: 2 preferred, 1 minimum (can use virtio if using a VM)
        * The first NIC will be wired into a network that routes to the internet. Internet access is required for installation of CentOS/RHEL 6.5
        * The second NIC (may be named eth1, em1, or en1) must be wired into the private space (192.168.124.0/24)
        * Note: It is possible to use a single NIC. In that case the default network address will be 192.168.124.0/24, the admin node IP address will be 192.168.124.10
        * Where a single NIC is used, the private admin network (192.168.124.0/24) must be capable of download of files from the internet or from a local caching server
    * Storage: A disk capacity of at least 10 GB is preferred. * Make sure you configure RAID on the drives before installing.
    * Ensure that all physical network transports are correctly configured and are operational - at least check/verify that:
        * All network cabling is in place
        * Network switches are turned on and configured correctly (ask network admin if necessary)
        * Keyboard,Video, and Mouse (if required) devices are connected and ready for use.
    * If using a virtual machine (VM), where VM motion (ability to migrated VMs across Hypervisor platforms) is required ensure that secure VM access is correctly configured and is operational.
    * Where network-managed power switches are in use, ensure that network access is secure from unwanted access.


##CentOS 6.5 installation
    Boot CentOS 6.5 x86_64 from pristine ISO media
    At the boot screen select "Install or upgrade an existing system", hit Enter
    Screen: "Welcome to CentOS for x86_64", select [Skip], hit Enter
    At the first graphical screen, "CentOS 6 Community ENTerprise Operating System", Click [Next]
    Screen: "What language would you like to use ...", Select "English (English)", Click [Next]
    Screen: "Select the appropriate keyboard ...", Select "U.S. English", Click [Next]
    Screen: "What type of devices will your installation involve\?", Select "Basic Storage Devices", Click [Next]
    Pop-up: "Storage Device Warning", Click [Yes, discard any data]
    Screen: "Please name this computer. The hostname ...", In the Hostname field enter: "admin.mytest.lcl"
        Click [Configure Network]
        Network configuration requirements depend on how many NICs are available, and on available network topology
            Single NIC configuration:
                Select "System eth0" (first NIC - on public network), Click [Edit]
                    Check "Connect automatically"
                    Click on [IPV4 Settings]
                    Select Method "Manual"
                    Click [Add]
                        Enter IP address: 192.168.124.10
                        Click on blank field below "Netmask". Enter: 24, or 255.255.255.0.
                        Enter DNS ip address (Ex.38.151.210.40)
                    Click [Apply]
            Dual NIC configuration:
                Select "System eth1" (first NIC - on public network), Click [Edit]
                    Check "Connect automatically"
                    Click [IPV4 Settings]
                    Select Method "Automatic (DHCP)" if appropriate, else configure network settings. (Need ip, netmask and gw) Click [Apply]
                Select "System eth0" (second NIC - on private admin network), Click [Edit]
                    Check "Connect automatically"
                    Click [IPV4 Settings]
                    Select Method "Manual"
                    Click [Add]
                        Enter IP address: 192.168.124.10
                        Click on blank field below "Netmask". Enter: 24, or 255.255.255.0, no gateway
                        Enter DNS ip address (Ex.38.151.210.40)
                    Click [Apply]
            Click [Close]
    Screen: "Please select the nearest city in your time zone:", Select your time zone, Click [Next]
    Screen: "The root account is used for administering the system. ...", Enter Root password "crowbar", Confirm: "crowbar", Click [Next]
    Popup: "Weak Password", Click [Use Anyway]
    Screen: "Which type of installation would you like?", Select "Use All Space", Click [Next]
    Popup: "Writing storage configuration to disk", Click [Write changes to disk]
    Screen: "The default installation of CentOS is a minimum install ...", Select "Basic Server", Click [Next]
    The system will now install. When finished, Click [Reboot]

Verify proxy operation before proceeding.  An example of how this validation may be completed is shown here:

    #> yum clean all
    #> yum makecache 

### Proxy alternative for YUM only ####

You can setup Yum to use a proxy and not have to add the proxy information to your bashrc script.  The benefit is that you will not have to unset the proxy when you doing local operations, but Gem will still require the above proxy information!

Follow the instructions at  https://www.centos.org/docs/5/html/yum/sn-yum-proxy-server.html
 

    # The proxy server - proxy server:port number
    proxy=http://mycache.mydomain.com:3128
    # The account details for yum connections 
    proxy_username=yum-user
    proxy_password=qwerty 

### END Proxy alternative ####

##OpenCrowbar installation
### Preparation

NOTE: This is preliminary information.  The specific steps outlined here will change soon and will need to be updated.

    Log into the CentOS 6.5 Admin node that was installed above, log in as the root user.

    Turn off the linux firewall with these commands: 
        # chkconfig iptables off
        # service iptables stop

    Create the dell-ocb yum repository file  

        cd /etc/yum.repos.d
        Using your favorite editor create a new repo file called "dell-ocb.repo"
        Add the following lines to the file

    [dell-ocb]
    name=repo for opencrowbar rpms
    baseurl=https://s3.amazonaws.com/opencrowbar/ocb
    enabled=1
    gpgcheck=0
    type=none
    autorefresh=1
    keeppackages=1

Save the file and continue.

    Verify that you can access the RPM repository
        yum repolist   

Verify that you see dell-ocb in the list and its status is >0 (the number of packages that were found)

        yum -y install http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-centos93-9.3-1.noarch.rpm
        yum -y install http://mirrors.servercentral.net/fedora/epel/6/i386/epel-release-6-8.noarch.rpm

         
If you are using VMs, now would be a good time to make a snapshot.
Another good reason to create a snapshot is the migration process doesn't at this date (3/24/2014) support upgrades.  
 
###Installing OpenCrowbar

        yum clean all; yum makecache
        yum install -y opencrowbar-core
            this will install opencrowbar core and dependent rpm packages
         ls /opt/opencrowbar
            verify that you have one directory (core) and one file (prep.sh)
            if so, then proceed to the following section.

###Enable WebUI / Connect via browser

    Execute the following commands:

    #> service iptables status (verified it was stopped)

            if not stopped, then run “service iptables stop”

    #> setenforce 0

    #> ifdown eth0 (the interface for the 192.168.124.10 IP)

    #> cd /opt/opencrowbar/core

    #> ./production/sh <FQDN>

 

Launch your web browser and connect to the IP address of the Admin node on port 3000 using a browser of choice (Google Chrome, or Internet Explorer) URL:http://192.168.124.10:3000

    Log in as user: crowbar
    Password: crowbar

##Known Issues:

  There is one known issue where the provisioner-server was unable to restart httpd and crashed.  The root cause of the issue is being investigated.   If you see this issue, your best bet (assuming that you created the SnapShot advice) is to jump to the "Updating Crowbar" section below and follow those instructions.  

 

If the above was followed sequentually it is safe to assume that OpenCrowbar was found to be operational. 
a) Updating OpenCrowbar

As of March 28, the instructions below should not be used as there are still many changes in the database schema occurring that prevent the RPM package from being up-gradable.  Until this churn quiets down your best bet is to follow these instructions:

  Revert your VM to the last Snapshot taken,  (You did follow the advice above to make a SnapShot, correct?)
  yum clean all; yum makecache
  yum install -y opencrowbar-core
  cd /opt/opencrowbar/core
  ./production.sh <FQDN>
  Launch your web browser and connect to the IP address of the Admin node on port 3000 using a browser of choice (Google Chrome, or Internet Explorer) URL:http://192.168.124.10:3000

##Known Limitations:

Please document all limitations that are discovered into this document.

RPM package installation/removal/update/upgrade processes confer many known limitations on third-party application-layer services such as OpenCrowbar, OpenStack, Hadoop. Here are a few issues that need to be defined and addressed:

  There is a latent need to document update and upgrade requirements and dependencies so that packaging methods can fully accommodate the scope of these so far as possible.
  The impact of RPM package updates on service continuity must be clearly defined. User-oriented documentation should set appropriate expectations for RPM update application.
  Risks to continuity of service, potential for loss of critical operational data needs to be identifies and documented.

Testing, validation and QA requirements for OpenCrowbar itself need to be documented separately and links to these documents should be inserted into this document.
