#!/bin/bash
# Wipe out stuff we want to re-fetch from scratch.
shopt -s nullglob extglob globstar
rm -rf /var/cache/crowbar \
    /usr/share/ruby/gems/* \
    /usr/lib/ruby/gems/* \
    /var/lib/gems/*/gems
touch /tmp/install_pkgs
./bootstrap.sh && \
    chef-solo -c /opt/opencrowbar/core/bootstrap/chef-solo.rb -o 'recipe[crowbar-bootstrap::cleanup]' && exit 0
echo "Failed to create a cleaned Docker image"
exit 1
