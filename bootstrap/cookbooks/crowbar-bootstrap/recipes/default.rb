#
# Cookbook Name:: crowbar-bootstrap
# Recipe:: default
#
# Copyright (C) 2014 Dell, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#

crowbar_yml = "/opt/opencrowbar/core/crowbar.yml"
sledgehammer_signature = "0f61af2f6be9288d5529e15aa223e036730a8387"

unless File.exists?(crowbar_yml)
  raise "No crowbar checkout to bootstrap!"
end

prereqs = YAML.load(File.open(crowbar_yml))

os_token="#{node["platform"]}-#{node["platform_version"]}"

os_pkg_type = case node["platform"]
              when "debian","ubuntu" then "debs"
              when "centos","redhat","opensuse","suse","fedora" then "rpms"
              else
                raise "Cannot figure out what package type we should use!"
              end

unless prereqs["os_support"].member?(os_token)
  raise "Cannot install crowbar on #{os_token}!  Can only install on one of #{prereqs["os_support"].join(" ")}"
end

tftproot = "/tftpboot"
sledgehammer_url="http://rcbdrepo.opencrowbar.org/sledgehammer/#{sledgehammer_signature}"
sledgehammer_dir="#{tftproot}/sledgehammer/#{sledgehammer_signature}"


repos = []
pkgs = []

# Find all the upstream repos and packages we will need.
if prereqs[os_pkg_type] && prereqs[os_pkg_type][os_token]
  repos << prereqs[os_pkg_type][os_token]["repos"]
  pkgs << prereqs[os_pkg_type][os_token]["build_pkgs"]
  pkgs << prereqs[os_pkg_type][os_token]["required_pkgs"]
end
repos << prereqs[os_pkg_type]["repos"]
pkgs << prereqs[os_pkg_type]["build_pkgs"]
pkgs << prereqs[os_pkg_type]["required_pkgs"]

Chef::Log.debug(repos)
Chef::Log.debug(pkgs)

repos.flatten!
repos.compact!
repos.uniq!
pkgs.flatten!
pkgs.compact!
pkgs.uniq!
pkgs.sort!

Chef::Log.debug(repos)

proxies = Hash.new
["http_proxy","https_proxy","no_proxy"].each do |p|
  next unless ENV[p] && !ENV[p].strip.empty?
  Chef::Log.info("Using #{p}='#{ENV[p]}'")
  proxies[p]=ENV[p].strip
end
unless proxies.empty?
  # Hack up /etc/environment to hold our proxy environment info
  template "/etc/environment" do
    source "environment.erb"
    variables(:values => proxies)
  end

  template "/etc/profile.d/proxy.sh" do
    source "proxy.sh.erb"
    variables(:values => proxies)
  end

  case node["platform"]
  when "redhat","centos"
    template "/etc/yum.conf" do
      source "yum.conf.erb"
      variables(
                :distro => node["platform"],
                :proxy => proxies["http_proxy"]
                )
    end
    bash "Disable fastestmirrors plugin" do
      code "sed -i '/enabled/ s/1/0/' /etc/yum/pluginconf.d/fastestmirror.conf"
    end
  end
end

file "/tmp/install_pkgs" do
  action :nothing
end

template "/tmp/required_pkgs" do
  source "required_pkgs.erb"
  variables( :pkgs => pkgs )
  notifies :create_if_missing, "file[/tmp/install_pkgs]",:immediately
end

case node["platform"]
when "debian","ubuntu"
  template "/etc/apt/sources.list.d/crowbar.list" do
    source "crowbar.list.erb"
    variables( :repos => repos )
    notifies :create_if_missing, "file[/tmp/install_pkgs]",:immediately
  end
when "centos","redhat","suse","opensuse","fedora"
  # Docker images do not have this, but the postgresql init script insists on it being present.
  file "/etc/sysconfig/network" do
    action :create
    content "NETWORKING=yes"
  end

  repos.each do |repo|
    repofile_path = case node["platform"]
                    when "centos","redhat" then "/etc/yum.repos.d"
                    when "suse","opensuse" then "/etc/zypp/repos.d"
                    else raise "Don't know where to put repo files for #{node["platform"]}'"
                    end
    rtype,rdest = repo.split(" ",2)
    case rtype
    when "rpm"
      rpm_file = rdest.split("/")[-1]
      bash "Install #{rpm_file}" do
        code "rpm -Uvh /tmp/#{rpm_file}"
        action :nothing
        ignore_failure true
        notifies :create_if_missing, "file[/tmp/install_pkgs]",:immediately
      end

      bash "Fetch #{rpm_file}" do
        code "curl -fgL -o '/tmp/#{rpm_file}' '#{rdest}'"
        not_if "test -f '/tmp/#{rpm_file}'"
        notifies :run, "bash[Install #{rpm_file}]",:immediately
      end

    when "bare"
      rname, rprio, rurl = rdest.split(" ",3)
      template "#{repofile_path}/crowbar-#{rname}.repo" do
        source "crowbar.repo.erb"
        variables(
                  :repo_name => rname,
                  :repo_prio => rprio,
                  :repo_url => rurl
                  )
        notifies :create_if_missing, "file[/tmp/install_pkgs]",:immediately
      end
    when "repo"
      rurl,rname = rdest.split(" ",2)
      template "#{repofile_path}/crowbar-#{rname}.repo" do
        source "crowbar.repo.erb"
        variables(
                  :repo_name => rname,
                  :repo_prio => 20,
                  :repo_url => rurl
                  )
        notifies :create_if_missing, "file[/tmp/install_pkgs]",:immediately
      end
    else
      raise "#{node["platform"]}: Unknown repo type #{rtype}"
    end
  end
else
  raise "Don't know how to update repositories for #{node["platform"]}"
end

bash "Install required files" do
  code case node["platform"]
       when "ubuntu","debian" then "apt-get -y update && apt-get -y --force-yes install #{pkgs.join(" ")} && rm /tmp/install_pkgs"
       when "centos","redhat","fedora" then "yum -y install #{pkgs.join(" ")} && rm /tmp/install_pkgs"
       when "suse","opensuse" then "zypper -n install #{pkgs.join(" ")} && rm /tmp/install_pkgs"
       else raise "Don't know how to install required files for #{node["platform"]}'"
       end
  only_if do ::File.exists?("/tmp/install_pkgs") end
end

directory "/var/run/sshd" do
  mode 0755
  owner "root"
  recursive true
end

bash "Regenerate Host SSH keys" do
  code "ssh-keygen -q -b 2048 -P '' -f /etc/ssh/ssh_host_rsa_key"
  not_if "test -f /etc/ssh/ssh_host_rsa_key"
end

# We need Special Hackery to run sshd in docker.
if File.file?("/.dockerenv")
  service "ssh" do
    service_name "sshd" if node["platform"] == "centos"
    start_command "/usr/sbin/sshd"
    stop_command "pkill -9 sshd"
    status_command "pgrep sshd"
    restart_command "pkill -9 sshd && /usr/sbin/sshd"
    action [:start]
  end
else
  service "ssh" do
    service_name "sshd" if node["platform"] == "centos"
    action [:enable, :start]
  end
end

directory "/root/.ssh" do
  action :create
  recursive true
  owner "root"
  mode 0755
end

directory "/home/crowbar/.ssh" do
  action :create
  owner "crowbar"
  group "crowbar"
  mode 0755
end

bash "Regenerate Crowbar SSH keys" do
  code "su -l -c 'ssh-keygen -q -b 2048 -P \"\" -f /home/crowbar/.ssh/id_rsa' crowbar"
  not_if "test -f /home/crowbar/.ssh/id_rsa"
end

bash "Enable root access" do
  cwd "/root/.ssh"
  code <<EOC
cat authorized_keys /home/crowbar/.ssh/id_rsa.pub >> authorized_keys.new
sort -u <authorized_keys.new >authorized_keys
rm authorized_keys.new
EOC
end

template "/home/crowbar/.ssh/config" do
  source "ssh_config.erb"
  owner "crowbar"
  group "crowbar"
  mode 0644
end

template "/etc/ssh/sshd_config" do
  source "sshd_config.erb"
  action :create
  notifies :restart, 'service[ssh]', :immediately
end

template "/etc/sudoers.d/crowbar" do
  source "crowbar_sudoer.erb"
  mode 0440
end

pg_conf_dir = "/var/lib/pgsql/data"
case node["platform"]
when "ubuntu","debian"
  pg_conf_dir = "/etc/postgresql/9.3/main"
  service "postgresql" do
    action [:enable, :start]
  end
  pg_database_dir = "/var/lib/postgresql/9.3/main/base"
  directory "#{pg_database_dir}" do
    owner "postgres"
  end
when "centos","redhat"
  pg_conf_dir = "/var/lib/pgsql/9.3/data"
  bash "Init the postgresql database" do
    code "service postgresql-9.3 initdb en_US.UTF-8"
    not_if do File.exists?("#{pg_conf_dir}/pg_hba.conf") end
  end
  service "postgresql" do
    service_name "postgresql-9.3"
    action [:enable, :start]
  end
  # Sigh, we need this so that the pg gem will install correctly
  bash "Make sure pg_config is in the PATH" do
    code "ln -sf /usr/pgsql-9.3/bin/pg_config /usr/local/bin/pg_config"
    not_if "which pg_config"
  end
end

# This will configure us to only listen on a local UNIX socket
template  "#{pg_conf_dir}/pg_hba.conf" do
  source "pg_hba.conf.erb"
  notifies :restart, "service[postgresql]",:immediately
end

bash "create crowbar user for postgres" do
  code "sudo -H -u postgres createuser -d -S -R -w crowbar"
  not_if "sudo -H -u postgres -- psql postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='crowbar'\" |grep -q 1"
end

(prereqs["gems"]["required_pkgs"] rescue []).each do |g|
  gem_package g do
    action :install
    options "--http-proxy #{proxies["http_proxy"]} --no-ri --no-rdoc --bindir /usr/local/bin"
  end
end

directory "#{tftproot}/gemsite/gems" do
  action :create
  recursive true
end

bash "Create skeleton local gemsite" do
  cwd "#{tftproot}/gemsite"
  code "gem generate_index"
  not_if "test -d '#{tftproot}/gemsite/quick'"
end

user "crowbar" do
  home "/home/crowbar"
  password '$6$afAL.34B$T2WR6zycEe2q3DktVtbH2orOroblhR6uCdo5n3jxLsm47PBm9lwygTbv3AjcmGDnvlh0y83u2yprET8g9/mve.'
  shell "/bin/bash"
  supports :manage_home => true
end

["/var/run/crowbar",
 "/var/cache/crowbar",
 "/var/cache/crowbar/cookbooks",
 "/var/cache/crowbar/gems",
 "/var/cache/crowbar/bin",
 "/var/log/crowbar"
].each do |d|
  directory d do
    owner "crowbar"
    action :create
    recursive true
  end
end

# warning for common error
if File.exists?("/opt/opencrowbar/core/rails/Gemfile.lock")
  Chef::Log.info("Using existing Gemfile.lock.  This will cause errors if Gemfile has been updated.  Delete lock and retry")
end 

bash "install required gems for Crowbar using Bundler" do
  code "su -l -c 'cd /opt/opencrowbar/core/rails; bundle install --path /var/cache/crowbar/gems --standalone --binstubs /var/cache/crowbar/bin' crowbar"
end

directory "#{tftproot}/discovery" do
  action :create
end

directory sledgehammer_dir do
  action :create
  recursive true
end

ruby_block "Download Sledgehammer #{sledgehammer_signature}" do
  block do
    files = ["initrd0.img","vmlinuz0","sha1sums"]
    Dir.chdir(sledgehammer_dir) do |path|
      unless File.file?("sha1sums")
        files.each do |f|
          dload = "#{sledgehammer_url}/#{f}"
          Chef::Log.info("Downloading #{dload}")
          raise("Cannot download #{dload}") unless system("curl -L -f -O '#{dload}'")
        end
      end
      raise("Sledgehammer image at #{sledgehammer_dir} corrupt or nonexistent") unless system("sha1sum -c sha1sums")
    end
  end
end

["initrd0.img", "vmlinuz0"].each do |f|
  link "#{tftproot}/discovery/#{f}" do
    action :create
    link_type :symbolic
    to "../sledgehammer/#{sledgehammer_signature}/#{f}"
  end
end
