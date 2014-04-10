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

class BarclampDns::Database < Role


  def on_node_create(n)
    Rails.logger.info("dns-database: Updating for new node #{n.name}")
    rerun_my_noderoles(n)
  end

  def on_node_change(n)
    rerun_my_noderoles(n)
  end

  def on_node_delete(n)
    to_enqueue = []
    node_roles.each do |nr|
      nr.with_lock('FOR NO KEY UPDATE') do
        hosts = nr.sysdata["crowbar"]["dns"]["hosts"]
        unless hosts.delete(n.name + ".")
          Rails.logger.error("dns-database: #{n.name} not in DNS database!")
          next
        end
        nr.update_column("sysdata",{"crowbar" => {"dns" => {"hosts" => hosts}}})
        to_enqueue << nr
      end
      Rails.logger.info("dns-database: Updating #{nr.name} sysdata for removed node #{n.name}")
    end
    to_enqueue.each {|nr| Run.enqueue(nr)}
  end

  private

  def rerun_my_noderoles(n)
    # Record our host entry information first.
    v4addrs,v6addrs = n.addresses.partition{|a|a.v4?}
    canonical_name = n.name + "."
    host = {}
    host["ip6addr"] ||= v6addrs.sort.first.addr unless v6addrs.empty?
    host["ip4addr"] ||= v4addrs.sort.first.addr unless v4addrs.empty?
    host["alias"] = n.alias if n.alias && !canonical_name.index(n.alias)
    to_enqueue = []
    node_roles.each do |nr|
      nr.with_lock('FOR NO KEY UPDATE') do
        hosts = (nr.sysdata["crowbar"]["dns"]["hosts"] rescue {})
        Rails.logger.debug("dns-database: Old host info: #{hosts.inspect}")
        if hosts[canonical_name] == host
          Rails.logger.info("dns-database: #{n.name} DNS information unchanged.")
          next
        end
        Rails.logger.info("dns-database: Updating #{nr.name} for new node #{n.name}")
        hosts[canonical_name] = host
        Rails.logger.debug("dns-database: New host info: #{hosts.inspect}")
        nr.update_column("sysdata", {"crowbar" => {"dns" => {"hosts" => hosts}}})
        to_enqueue << nr
      end
    end
    to_enqueue.each {|nr| Run.enqueue(nr)}
  end
end
