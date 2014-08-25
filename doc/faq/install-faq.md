## Q: `crowbar converge` keeps failing with httpd installs when running `./tools/docker-admin centos ./production.sh my.domain.here`

Converge failed, so I checked the logs and saw Chef failing to install httpd.  So I ran it on the command line and got the full error:
```
error: unpacking of archive failed on file /usr/sbin/suexec: cpio: cap_set_file

newgoliath [3:14 PM] Installing : httpd-2.2.22-1.ceph.el6.x86_64                                                                   1/1
Error unpacking rpm package httpd-2.2.22-1.ceph.el6.x86_64
error: unpacking of archive failed on file /usr/sbin/suexec: cpio: cap_set_file

newgoliath [3:14 PM] Linux judd-m6600 3.13.0-32-generic #57-Ubuntu SMP Tue Jul 15 03:51:08 UTC 2014 x86_64 x86_64 x86_64 GNU/Linux

newgoliath [3:16 PM]3:16 bash-4.1# sestatus
SELinux status:                 disabled 
```


## A: Turns out it has nothing to do with SELinux.  Make sure your docker server is running with `-s devicemapper`.  On Ubuntu edit `/etc/default/docker` to include it.  On RedHat derived, edit `/etc/sysconfig/docker`.  All better!

