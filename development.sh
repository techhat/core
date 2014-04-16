#!/bin/bash
export RAILS_ENV=development
(./bootstrap.sh && \
    ./setup/01-crowbar-rake-tasks.install && \
    ./setup/02-make-machine-key.install)
. /etc/profile
/bin/bash -i
