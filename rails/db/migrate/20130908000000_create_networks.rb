# Copyright 2013, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

class CreateNetworks < ActiveRecord::Migration
  def change
    create_table "networks" do |t|
      t.references   :deployment
      t.string       :name,       null: false, index: { unique: true }
      t.string       :description,null: true
      t.integer      :order,      null: false, default: 1000
      t.integer      :vlan,       null: false, default: 0
      t.boolean      :use_vlan,   null: false, default: false
      t.boolean      :use_bridge, null: false, default: false
      t.integer      :team_mode,  null: false, default: 5
      t.boolean      :use_team,   null: false, default: false
      t.string       :v6prefix
      # This contains abstract interface names seperated by a comma.
      # It could be normalized, but why bother for now.
      t.string       :conduit,    null: false
      t.timestamps
    end

    create_table "network_routers" do |t|
      t.references   :network
      t.string       :address,    null: false
      t.integer      :pref,       null: false, default: 65536
      t.timestamps
    end

    create_table "network_ranges" do |t|
      t.string       :name,       null: false
      t.references   :network
      # Both of these should also be CIDRs.
      t.string       :first,      null: false
      t.string       :last,       null: false
      t.timestamps
    end
    add_index "network_ranges", [:network_id, :name], unique: true

    create_table "network_allocations" do |t|
      t.references   :node
      t.references   :network
      t.references   :network_range
      t.string       :address,    null: false, index: { unique: true }
      t.timestamps
    end

    create_view :dns_database, "select n.name as name,
                                       n.alias as cname,
                                       a.address as address,
                                       net.name as network
                                from nodes n
                                inner join network_allocations a on n.id = a.node_id
                                inner join networks net on net.id = a.network_id"

    create_view :dhcp_database, "select n.name as name,
                                        n.bootenv as bootenv,
                                        a.address as address,
                                        json_extract_path(n.discovery,'ohai','network','interfaces') as discovered_macs,
                                        json_extract_path(n.hint,'admin_macs') as hinted_macs
                                 from nodes n
                                 inner join network_allocations a on a.node_id = n.id
                                                                  and family(a.address::inet) = 4
                                 inner join networks net on a.network_id = net.id and net.name = 'admin'
                                 inner join node_roles nr on nr.node_id = n.id
                                 inner join roles r on nr.role_id = r.id and r.name = 'crowbar-managed-node'
                                 where json_extract_path(n.hint,'admin_macs') is not null
                                 or json_extract_path(n.discovery,'ohai','network','interfaces') is not null"

    create_view :docker_database, "select n.name as name,
                                       a.address as address
                                from nodes n
                                inner join network_allocations a on n.id = a.node_id
                                inner join networks net on net.id = a.network_id
                                inner join node_roles nr on nr.node_id = n.id
                                inner join roles r on nr.role_id = r.id
                                where net.name = 'admin'
                                and r.name = 'crowbar-docker-node'"
  end
end
