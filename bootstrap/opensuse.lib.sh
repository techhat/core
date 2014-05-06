#!/bin/bash
install_prereqs() {
    zypper -n update
    zypper -n install curl ruby20 ruby20-devel ruby20-devel-extra
}
