Q:  crowbar converge keeps failing with httpd installs when running ./tools/docker-admin centos ./production.sh my.domain.here

A: Make sure your docker server is running with -s devicemapper.  On Ubuntu edit /etc/default/docker to include it.

