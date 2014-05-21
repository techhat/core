#!/bin/bash

server_fqdn=$(read_attribute "chefjig/server/fqdn")
server_address=$(read_attribute "chefjig/server/address")
server_url=$(read_attribute "chefjig/server/url")
server_deploy=$(read_attribute "chefjig/server/deploy")
admin_client=$(read_attribute "chefjig/server/client-name")
admin_clientkey=$(read_attribute "chefjig/server/client-key")

die() {
    echo "$(date '+%F %T %z'): $@"
    exit 1
}
if [[ $server_deploy = true  && ! -d /etc/chef-server ]]; then
    if [[ -f /etc/redhat-release || -f /etc/centos-release ]]; then
        OS=redhat
        yum install -y chef chef-server
    elif [[ -d /etc/apt ]]; then
        OS=ubuntu
        apt-get -y install chef chef-server
    elif [[ -f /etc/SuSE-release ]]; then
        if grep -q openSUSE /etc/SuSE-release; then
            OS=opensuse
            zypper install -y -l chef chef-server
        else
            OS=suse
        fi
    else
        die "Staged on to unknown OS media!"
    fi

    if [[ ! -x /etc/init.d/chef-server ]]; then
        # Set up initial config
        mkdir -p /etc/chef-server

        # Patch a couple of things to make the omniinstller work everywhere it needs to
        [[ -f /opt/chef-server/embedded/cookbooks/runit/recipes/systemd.rb ]] || (
            cd /opt/chef-server/embedded/cookbooks
            cat >runit/files/default/chef-server-runsvdir.service <<'EOF'
[Unit]
Description=Embedded Chef Server Service Runner
Documentation=http://getchef.com
After=network.target

[Service]
ExecStart=/opt/chef-server/embedded/bin/runsvdir-start
ExecStopPost=pkill -HUP -P 1 runsv$$

[Install]
WantedBy=multi-user.target
EOF
        cat >runit/recipes/default.rb <<'EOF'
#
# Cookbook Name:: runit
# Recipe:: default
#
# Copyright 2008-2010, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

case
when File.exists?("/.dockerinit")
  # Inside Docker, assume no init system exists.
  # Instead, just fire off runsvdir and hope it never dies.
  bash "Launch runsvdir in the background for Docker" do
    code "nohup /opt/chef-server/embedded/bin/runsvdir-start >/dev/null &"
    not_if "pgrep -f 'runsvdir -P /opt/chef-server/service'"
  end

when File.directory?("/etc/systemd")
  # We are running under SystemD
  include_recipe "runit::systemd"
when File.directory?("/etc/init")
  # We are running using Upstart
  include_recipe "runit::upstart"
when File.exists?("/etc/inittab")
  # Assume sysv-style init scripts
  include_recipe "runit::sysvinit"
else
  raise "Cannot determine what init system we are using for runit!"
end

EOF
        cat >chef-server/recipes/systemd.rb <<'EOF'
#
# Cookbook Name:: runit
# Recipe:: default
#
# Copyright 2008-2010, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

cookbook_file "/etc/systemd/system/chef-server-runsvdir.service" do
  owner "root"
  group "root"
  mode "0644"
  source "chef-server-runsvdir.service"
  notifies :run, "execute[systemctl enable chef-server-runsvdir.service]", :immediately
end

execute "systemctl enable chef-server-runsvdir.service" do
  action :nothing
  retries 30
end

execute "systemctl start chef-server-runsvdir.service" do
  retries 30
end

EOF
          patch -p3 -l <<'EOF'
diff --git a/files/chef-server-cookbooks/chef-server/recipes/postgresql.rb b/files/chef-server-cookbooks/chef-server/recipe
index 7928d44..ebb1afb 100644
--- a/files/chef-server-cookbooks/chef-server/recipes/postgresql.rb
+++ b/files/chef-server-cookbooks/chef-server/recipes/postgresql.rb
@@ -56,34 +56,23 @@ PATH=#{node['chef_server']['postgresql']['user_path']}
 EOH
 end

-if File.directory?("/etc/sysctl.d") && File.exists?("/etc/init.d/procps")
-  # smells like ubuntu...
-  service "procps" do
-    action :nothing
-  end
-
-  template "/etc/sysctl.d/90-postgresql.conf" do
-    source "90-postgresql.conf.sysctl.erb"
-    owner "root"
-    mode  "0644"
-    variables(node['chef_server']['postgresql'].to_hash)
-    notifies :start, 'service[procps]', :immediately
-  end
-else
-  # hope this works...
-  execute "sysctl" do
-    command "/sbin/sysctl -p /etc/sysctl.conf"
-    action :nothing
-  end
-
-  bash "add shm settings" do
-    user "root"
-    code <<-EOF
-      echo 'kernel.shmmax = #{node['chef_server']['postgresql']['shmmax']}' >> /etc/sysctl.conf
-      echo 'kernel.shmall = #{node['chef_server']['postgresql']['shmall']}' >> /etc/sysctl.conf
-    EOF
-    notifies :run, 'execute[sysctl]', :immediately
-    not_if "egrep '^kernel.shmmax = ' /etc/sysctl.conf"
+sysv_mem_keys = ["shmmax","shmall"]
+sysv_mem = Hash.new
+sysv_mem_keys.each do |k|
+  sysv_mem[k] = IO.read("/proc/sys/kernel/#{k}").strip.to_i
+  if sysv_mem[k] < node['chef_server']['postgresql'][k]
+    # Set the sysctl value directly.
+    execute "sysctl kernel.#{k}=#{node['chef_server']['postgresql'][k]}"
+    shmem_setting = "kernel.#{k} = #{node['chef_server']['postgresql'][k]}"
+    shmem_target = if File.directory?("/etc/sysctl.d")
+                     "/etc/sysctl.d/90-chef-server-postgresql.conf"
+                   else
+                     "/etc/sysctl.conf"
+                   end
+    bash "Save #{k} postgresql setting for next reboot" do
+      code "echo '#{shmem_setting}' >> '#{shmem_target}'"
+      not_if "fgrep -q '#{shmem_setting}' #{shmem_target}"
+    end
   end
 end

@@ -130,6 +119,8 @@ if node['chef_server']['bootstrap']['enable']
   end
 end

+ENV['PGPORT'] = (node['chef_server']['postgresql']['port'] || 5432).to_s
+
 ###
 # Create the database, migrate it, and create the users we need, and grant them
 # privileges.

EOF


)

        # Set sane-ish defaults for chef-server.
        cat >/etc/chef-server/chef-server.rb <<EOF
api_fqdn='$server_address'
bookshelf['vip']='$server_address'
nginx['enable_ipv6']=true
nginx['url']='$server_url'
nginx['server_name']='$server_address'
postgresql['port'] = 5439
postgresql['effective_cache_size'] = '128MB'
postgresql['shared_buffers'] = '128MB'
postgresql['work_mem'] = '1MB'
postgresql['listen_addresses']=''
EOF

        chef-server-ctl reconfigure || exit 1
        chef-server-ctl test || {
            echo "Could not bring up valid chef server!"
            exit 1
        }
        mkdir -p /etc/chef
        ln -s /etc/chef-server/chef-webui.pem /etc/chef/webui.pem
        ln -s /etc/chef-server/chef-validator.pem /etc/chef/validation.pem
        cat > /etc/init.d/chef-server <<EOF
#!/bin/bash
### BEGIN INIT INFO
# Provides:          chef-server
# Required-Start:    \$syslog \$network \$named
# Required-Stop:     \$syslog \$network \$named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start chef-server at boot time
# Description:       Enable chef server
### END INIT INFO

# chkconfig 2345 10 90
# description Chef Server wrapper
exec chef-server-ctl "\$@"
EOF
        chmod 755 /etc/init.d/chef-server
        if [[ $OS = ubuntu ]]; then
            update-rc.d chef-server defaults
            update-rc.d chef-server enable
        else
            chkconfig chef-server on
        fi
    fi
fi
# Create a client for the Crowbar user.
if [[ ! -e /home/crowbar/.chef/knife.rb ]]; then
    echo "Creating chef client for Crowbar on admin node"
    mkdir /home/crowbar/.chef
    KEYFILE="/home/crowbar/.chef/$admin_client.pem"
    if [[ $server_deploy = true ]]; then
        EDITOR=/bin/true knife client create "$admin_client" \
            -a --file "$KEYFILE" -u chef-webui \
            -k /etc/chef-server/chef-webui.pem
    else
        echo "$admin_client" > "$KEYFILE"
    fi
    cat > /home/crowbar/.chef/knife.rb <<EOF
log_level                :info
log_location             STDOUT
node_name                '$admin_client'
client_key               '$KEYFILE'
chef_server_url          '$server_url'
syntax_check_cache_path  '/home/crowbar/.chef/syntax_check_cache'
EOF
    chown -R crowbar:crowbar /home/crowbar/.chef/
fi

# Once we have a working client, upload all the cookbooks we care about.
/opt/opencrowbar/core/bin/chef-cookbook-upload
