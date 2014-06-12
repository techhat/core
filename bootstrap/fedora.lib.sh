#!/bin/bash
install_ruby() {
    yum -y upgrade
    yum -y install ruby ruby-devel curl
     which chef-solo || \
        yum -y install \
        https://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-11.12.8-2.el6.x86_64.rpm
}
