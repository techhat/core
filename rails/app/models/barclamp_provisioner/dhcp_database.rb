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
#

class BarclampProvisioner::DhcpDatabase < Role

  def on_node_create(node)
    return unless node.roles.exists?(name: "crowbar-managed-node") || (node.bootenv == "sledgehammer")
    Rails.logger.info("provisioner-dhcp-database: Updating for added node #{node.name}")
    rerun_my_noderoles(node) 
  end

  def on_node_change(node)
    return unless node.roles.exists?(name: "crowbar-managed-node") || (node.bootenv == "sledgehammer")
    Rails.logger.info("provisioner-dhcp-database: Updating for changed node #{node.name}")
    rerun_my_noderoles(node)
  end

  def on_node_delete(node)
    Rails.logger.info("provisioner-dhcp-database: Updating for deleted node #{node.name}")
    node_roles.each do |nr|
      nr.with_lock('FOR NO KEY UPDATE') do
        hosts = nr.sysdata["crowbar"]["dhcp"]["clients"]
        next unless hosts.delete(node.name)
        nr.update_column("sysdata",{"crowbar" => {"dhcp" => {"clients" => hosts}}})
        to_enqueue << nr
      end
    end
    to_enqueue.each {|nr| Run.enqueue(nr)}
  end

  def rerun_my_noderoles(node)
    host = {}
    v4addr = node.addresses.reject{|a|a.v6?}.sort.first.to_s
    # We have not been allocated an address yet, do nothing here.
    return if v4addr.nil? || v4addr.empty?
    # scan interfaces to capture all the mac addresses discovered
    ints = (node.discovery["ohai"]["network"]["interfaces"] rescue nil)
    mac_list = Attrib.get("hint-admin-macs",node) || []
    unless ints.nil?
      ints.each do |net, net_data|
        net_data.each do |field, field_data|
          next if field != "addresses"
          field_data.each do |addr, addr_data|
            next if addr_data["family"] != "lladdr"
            mac_list << addr unless mac_list.include? addr
          end
        end
      end
    end
    host["mac_addresses"] =  mac_list.map{|m|m.upcase}.sort.uniq
    host["v4addr"] = v4addr
    host["bootenv"] = node.bootenv
    # we need to have at least 1 mac (from preload or inets)
    return unless mac_list.length > 0
    to_enqueue = []
    node_roles.each do |nr|
      nr.with_lock('FOR NO KEY UPDATE') do
        hosts = (nr.sysdata["crowbar"]["dhcp"]["clients"] rescue {})
        next if hosts[node.name] == host
        hosts[node.name] = host
        nr.update_column("sysdata",{"crowbar" => {"dhcp" => {"clients" => hosts}}})
        to_enqueue << nr
      end
    end
    to_enqueue.each { |nr| Run.enqueue(nr) }
  end
end
