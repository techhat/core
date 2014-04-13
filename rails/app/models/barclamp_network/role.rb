# Copyright 2014, Dell
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

class BarclampNetwork::Role < Role

  def network
    Network.where(:name => "#{name.split('-',2)[-1]}").first
  end

  def conduit?
    true
  end

  # Our template == the template that our matching network definition has.
  # For now, just hashify the stuff we care about[:ranges]
  def template
    { "crowbar" => { "network" => { network.name => network.to_template } }  }
  end

  def jig_role(nr)
    { "name" => nr.role.name,
      "chef_type" => "role",
      "json_class" => "Chef::Role",
      "description" => I18n.t('automatic_item_by', :item=>nr.role.name, :name=>"Crowbar"),
      "run_list" => ["recipe[network]"]}
  end

  def sysdata(nr)
    our_addrs = network.node_allocations(nr.node).map{|a|a.to_s}
    res = {"crowbar" => {
        "network" => {
          network.name => {
            "addresses" => our_addrs
          }
        }
      }
    }
    # Pick targets for ping testing.
    target = node_roles.partition{|tnr|tnr.id != nr.id}.flatten.detect{|tnr|tnr.active?}
    if target
      res["crowbar"]["network"][network.name]["targets"] = network.node_allocations(target.node).map{|a|a.to_s}
    end
    res
  end

  def on_proposed(nr)
    node = nr.node(true)
    return if network.allocations.node(node).count != 0
    # v4 automatic address allocation handling
    addr_range = if node.is_admin? && network.ranges.exists?(name: "admin")
                   network.ranges.find_by!(name: "admin")
                 else
                   network.ranges.find_by!(name: "host")
                 end
    # get the suggested ip address (if any) - nil = automatically assign
    suggestion = node.attribs.find_by!(name: "hint-#{network.name}-v4addr").get(node)
    addr_range.allocate(nr.node, suggestion)
    # v6 automatic address handling
    addr_range = network.ranges.find_by(name: "host-v6")
    return unless addr_range
    suggestion = node.attribs.find_by!(name: "hint-#{network.name}-v6addr").get(node) ||
      node.auto_v6_address(network)
    addr_range.allocate(nr.node, suggestion)
  end

end
