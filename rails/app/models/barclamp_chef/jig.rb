# Copyright 2013, Dell
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

require 'json'
require 'chef'
require 'fileutils'
require 'thread'

class BarclampChef::Jig < Jig
  @@load_role_mutex ||= Mutex.new

  def make_run_list(nr)
    runlist = Array.new
    runlist << "recipe[barclamp]"
    runlist << "recipe[ohai]"
    runlist << "recipe[utils]"
    runlist << "role[#{nr.role.name}]"
    Rails.logger.info("Chefjig: discovered run list: #{runlist}")
    Chef::RunList.new(*runlist)
  end

  def stage_run(nr)
    return {
      :runlist => make_run_list(nr),
      :data => super(nr)
    }
  end

  def run(nr,data)
    prep_chef_auth
    unless (Chef::Role.load(nr.role.name) rescue nil)
      # If we did not find the role in question, then the chef
      # data from the barclamp has not been uploaded.
      # Do that here, and then set chef_role.
      chef_path = File.join(nr.barclamp.source_path, on_disk_name)
      unless File.directory?(chef_path)
        raise("No Chef data at #{chef_path}")
      end
      role_path = "#{chef_path}/roles"
      data_bag_path = "#{chef_path}/data_bags"
      user_data_bag_path = "/var/tmp/barclamps/#{nr.role.barclamp.name}/chef"
      cookbook_path = "#{chef_path}/cookbooks"
      [data_bag_path,user_data_bag_path].each do |db_path|
        Dir.glob(File.join(db_path,"*.json")).each do |d|
          data_bag_name = d.split('/')[-1]
          next unless File.directory?(d)
          next if (data_bag_name == "..") || (data_bag_name == ".")
          Chef::DataBag.load(data_bag_name) || Chef::DataBag.new(data_bag_name).create
          data_bag_item_data = Yajl::Parser.parse(IO.read(d))
          data_bag_item = Chef::DataBagItem.load(data_bag_name,data_bag_item_data["id"])
          if data_bag_item
            unless data_bag_item.raw_data == data_bag_item_data
              data_bag_item.raw_data = data_bag_item_data
              data_bag_item.save
            end
          else
            data_bag_item = Chef::DataBagItem.new
            data_bag_item.raw_data = data_bag_item_data
            data_bag_item.data_bag = data_bag_name
            data_bag_item.create
          end
        end if File.directory?(db_path)
      end
      if nr.role.respond_to?(:jig_role)
        Chef::Role.json_create(nr.role.jig_role(nr)).save
      elsif File.exist?("#{role_path}/#{nr.role.name}.rb")
        @@load_role_mutex.synchronize do
          Chef::Config[:role_path] = role_path
          Chef::Role.from_disk(nr.role.name, "ruby").save
        end
      else
        raise "Could not find or synthesize a Chef role for #{nr.name}"
      end
    end
    chef_node, chef_noderole = chef_node_and_role(nr.node)
    chef_noderole.default_attributes(data[:data])
    chef_noderole.run_list(data[:runlist])
    chef_noderole.save
    # For now, be bloody stupid.
    # We should really be much more clever about building
    # and maintaining the run list, but this will do to start off.
    chef_node.attributes.normal = {}
    chef_node.run_list(Chef::RunList.new(chef_noderole.to_s))
    chef_node.save
    # SSH into the node and kick chef-client.
    # If it passes, go to ACTIVE, otherwise ERROR.
    out,err,ok = nr.node.ssh("chef-client")
    raise("Chef jig run for #{nr.name} failed\nOut: #{out}\nErr:#{err}") unless ok.success?
    # Reload the node, find any attrs on it that map to ones this
    # node role cares about, and write them to the wall.
    Rails.logger.info("Chef jig: Reloading Chef objects")
    chef_node, chef_noderole = chef_node_and_role(nr.node)
    NodeRole.transaction do
      wall = mash_to_hash(chef_node.attributes.normal)
      discovery = {"ohai" => mash_to_hash(chef_node.attributes.automatic.to_hash)}
      Rails.logger.debug("Chef jig: Saving runlog")
      nr.update!(runlog: out)
      Rails.logger.debug("Chef jig: Saving wall")
      nr.update!(wall: wall)
      Rails.logger.debug("Chef jig: Saving discovery attributes")
      nr.node.discovery_merge(discovery)
    end
  end

  def create_node(node)
    Rails.logger.info("ChefJig Creating node #{node.name}")
    prep_chef_auth
    cb_nodename = node.name
    cb_noderolename = node_role_name(node)
    chef_node = Chef::Node.build(cb_nodename)
    chef_role = Chef::Role.new
    chef_role.name(cb_noderolename)
    chef_client = Chef::ApiClient.new
    chef_client.name(node.name)
    [chef_node.save, chef_role.save, chef_client.save]
  end

  def delete_node(node)
    prep_chef_auth
    Rails.logger.info("ChefJig Deleting node #{node.name}")
    chef_client = (Chef::ApiClient.load(node.name) rescue nil)
    chef_client.destroy if chef_client
    chef_node_and_role(node).each do |i|
      i.destroy
    end
  end

  private

  def node_role_name(node)
    "crowbar-#{node.name.tr(".","_")}"
  end

  
  def mash_to_hash(src)
    case
    when src.kind_of?(Hash)
      res = Hash.new
      src.each do |k,v|
        res[k.to_s] = mash_to_hash(v)
      end
      res
    when src.kind_of?(Array)
      res = Array.new
      src.each do |v|
        res << mash_to_hash(v)
      end
      res
    else
      src
    end
  end

  def chef_node_and_role(node)
    prep_chef_auth
    [Chef::Node.load(node.name),Chef::Role.load(node_role_name(node))]
  end

  def prep_chef_auth
    reload if server.nil? || server.empty?
    Chef::Config[:client_key] = key
    Chef::Config[:chef_server_url] = server
    Chef::Config[:node_name] = client_name
  end

end # class
