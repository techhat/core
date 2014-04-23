#!/bin/bash

[[ -x /etc/init.d/crowbar_join.sh || \
    -x /etc/init.d/crowbar || \
    -x /usr/sbin/crowbar ]] && exit 0

set -x
webserver=$(read_attribute "crowbar/provisioner/server/webserver")
while true; do
    curl -s -f -L -o /tmp/bootstate "$webserver/nodes/$(hostname -f)/bootstate" && \
        [[ -f /tmp/bootstate && $(cat /tmp/bootstate) = *-install ]] && break
    sleep 1
done

