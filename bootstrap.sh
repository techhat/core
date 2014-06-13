#!/bin/bash
set -e
# If we have an http_proxy variable, make sure we have a semi-cromulent
# no_proxy variable as well.
if [[ $http_proxy && !$no_proxy ]] ; then
    export no_proxy="127.0.0.1,localhost,::1"
fi

prefix_recipes='recipe[barclamp],recipe[ohai],recipe[utils]'
boot_recipes="$prefix_recipes,recipe[crowbar-bootstrap]"
database_recipes="$prefix_recipes,recipe[crowbar-bootstrap::postgresql]"
proxy_recipes="$prefix_recipes,recipe[crowbar-squid]"

# Figure out what we are running on.
if [[ -f /etc/system-release ]]; then
    read DISTRIB_ID _t DISTRIB_RELEASE rest < /etc/system-release
elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRIB_ID="$ID"
    DISTRIB_RELEASE="$VERSION_ID"
elif [[ -f /etc/lsb-release ]]; then
    . /etc/lsb-release
else
    echo "Cannot figure out what we are running on!"
fi
DISTRIB_ID="${DISTRIB_ID,,}"
OS_TOKEN="$DISTRIB_ID-$DISTRIB_RELEASE"
export OS_TOKEN DISTRIB_ID DISTRIB_RELEASE

if [[ -f bootstrap/${OS_TOKEN}.lib.sh ]]; then
    . "bootstrap/${OS_TOKEN}.lib.sh"
elif [[ -f bootstrap/${DISTRIB_ID}.lib.sh ]]; then
    . "bootstrap/${DISTRIB_ID}.lib.sh"
else
    echo "Cannot source a bootstrap library for $OS_TOKEN!"
    exit 1
fi

which curl &>/dev/null || \
    install_prereqs
which chef-solo &>/dev/null || \
    curl -L https://www.opscode.com/chef/install.sh | bash
chef-solo -c /opt/opencrowbar/core/bootstrap/chef-solo.rb -o "${boot_recipes}" || {
    echo "Chef-solo bootstrap run failed"
    exit 1
}
