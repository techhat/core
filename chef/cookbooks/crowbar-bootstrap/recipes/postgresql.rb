
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
when "opensuse", "suse"
  bash "Init the postgresql database" do
    code <<EOC
su -l -c 'initdb --locale=en_US.UTF-8 -D #{pg_conf_dir}' postgres
sed -i -e '/POSTGRES_DATADIR/ s@=.*$@="#{pg_conf_dir}"@' /etc/sysconfig/postgresql
EOC
    not_if do File.exists?("#{pg_conf_dir}/pg_hba.conf") end
  end
  service "postgresql" do
    action [:enable, :start]
  end
end

# This will configure us to only listen on a local UNIX socket
template "#{pg_conf_dir}/postgresql.conf" do
  source "postgresql.conf.erb"
  notifies :restart, "service[postgresql]", :immediately
end

template  "#{pg_conf_dir}/pg_hba.conf" do
  source "pg_hba.conf.erb"
  notifies :restart, "service[postgresql]",:immediately
end

bash "create crowbar user for postgres" do
  code "sudo -H -u postgres createuser -d -S -R -w crowbar"
  not_if "sudo -H -u postgres -- psql postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='crowbar'\" |grep -q 1"
end

