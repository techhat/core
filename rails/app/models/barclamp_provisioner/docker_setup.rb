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

class BarclampProvisioner::DockerSetup < Role

  def on_node_create(node)
    rerun_my_noderoles(node)
  end

  def on_node_change(node)
    rerun_my_noderoles(node)
  end

  def on_node_delete(node)
    to_enqueue = []
    node_roles.each do |nr|
      nr.with_lock('FOR NO KEY UPDATE') do
        hosts = nr.sysdata["crowbar"]["docker"]["clients"]
        next unless hosts.delete(node.name)
        nr.update_column("sysdata",{"crowbar" => {"docker" => {"clients" => hosts}}})
        to_enqueue << nr
      end
    end
    to_enqueue.each {|nr| Run.enqueue(nr)}
  end

  def rerun_my_noderoles(node)
    host = {
      "addresses" => node.addresses.map{|a|a.to_s},
      "image" => "opencrowbar/ubuntu-slave"
    }
    to_enqueue = []
    node_roles.each do |nr|
      nr.with_lock('FOR NO KEY UPDATE') do
        hosts = (nr.sysdata["crowbar"]["docker"]["clients"] rescue {})
        next if hosts[node.name] == host
        hosts[node.name] = host
        nr.update_column("sysdata",{"crowbar" => {"docker" => {"clients" => hosts}}})
        to_enqueue << nr
      end
    end
    to_enqueue.each { |nr| Run.enqueue(nr) }
  end
end
