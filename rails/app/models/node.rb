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
#

require 'digest/md5'
require 'open4'

class Node < ActiveRecord::Base

  before_validation :default_population
  after_commit :on_create_hooks, on: :create
  after_commit :after_commit_handler, on: :update
  after_commit :on_destroy_hooks, on: :destroy

  # Make sure we have names that are legal
  # requires at least three domain elements "foo.bar.com", cause the admin node shouldn't
  # be a top level domain ;p
  FQDN_RE = /\A([a-zA-Z0-9_\-]{1,63}\.){2,}(?:[a-zA-Z]{2,})\z/
  # for to_api_hash
  API_ATTRIBUTES = ["id", "name", "description", "order", "admin", "available", "alive",
                    "allocated", "created_at", "updated_at"]
  #
  # Validate the name should unique (no matter the case)
  # and that it starts with a valid FQDN
  #
  validates_uniqueness_of :name, :case_sensitive => false, :message => I18n.t("db.notunique", :default=>"Item must be unique")
  validates_format_of     :name, :with=>FQDN_RE, :message => I18n.t("db.fqdn", :default=>"Name must be a fully qualified domain name.")
  validates_length_of     :name, :maximum => 255

  # TODO: 'alias' will move to DNS BARCLAMP someday, but will prob hang around here a while
  validates_uniqueness_of :alias, :case_sensitive => false, :message => I18n.t("db.notunique", :default=>"Name item must be unique")
  validates_format_of :alias, :with=>/\A[A-Za-z0-9\-]*[A-Za-z0-9]\z/, :message => I18n.t("db.fqdn", :default=>"Alias is not valid.")
  validates_length_of :alias, :maximum => 100

  has_and_belongs_to_many :groups, :join_table => "node_groups", :foreign_key => "node_id"

  has_many    :node_roles,         :dependent => :destroy
  has_many    :runs,               :dependent => :destroy
  has_many    :roles,              :through => :node_roles
  has_many    :deployments,        :through => :node_roles
  has_many    :network_allocations,:dependent => :destroy
  belongs_to  :deployment
  belongs_to  :target_role,        :class_name => "Role", :foreign_key => "target_role_id"

  alias_attribute :ips,                :network_allocations

  scope    :admin,              -> { where(:admin => true) }
  scope    :alive,              -> { where(:alive => true) }
  scope    :available,          -> { where(:available => true) }

  # Get all the attributes applicable to a node.
  # This includes:
  # * All attributes that are defined for our node roles, by virtue of
  #   being defined as part of the role that the node role is bound to, and
  # * All attributes that are not defined as part of a node.
  def attribs
    Attrib.where(["attribs.role_id IS NULL OR attribs.role_id in (select role_id from node_roles where node_id = ?)",self.id])
  end

  def <=>(other)
    self.name <=> other.name
  end

  # look at Node state by scanning all node roles.
  def state
    Node.transaction do
      node_roles.each do |nr|
        if nr.proposed?
          return NodeRole::PROPOSED
        elsif nr.error?
          return NodeRole::ERROR
        elsif [NodeRole::BLOCKED, NodeRole::TODO, NodeRole::TRANSITION].include? nr.state
          return NodeRole::TODO
        end
      end
    end
    return NodeRole::ACTIVE
  end

  # returns a hash with all the node error status information
  def status
    s = []
    Node.transaction do
      node_roles.each { |nr| s[nr.id] = nr.status if nr.error?  }
    end
  end

  def shortname
    self.name.split('.').first
  end

  def login
    "root@#{shortname}"
  end

  def ssh(cmd)
    run_on(". /etc/profile; exec ssh -l root #{address.addr} -- #{cmd}")
  end

  def scp_from(remote_src, local_dest, opts="")
    run_on("exec scp #{opts} root@[#{address.addr}]:#{remote_src} #{local_dest}")
  end

  def scp_to(local_src, remote_dest, opts="")
    run_on("exec scp #{opts} #{local_src} root@[#{address.addr}]:#{remote_dest}")
  end

  def self.name_hash
    Digest::SHA1.hexdigest(Node.select(:name).order("name ASC").map{|n|n.name}.join).to_i(16)
  end

  def v6_hostpart
    d = Digest::MD5.hexdigest(name)
    "#{d[16..19]}:#{d[20..23]}:#{d[24..27]}:#{d[28..32]}"
  end

  def auto_v6_address(net)
    return nil if net.v6prefix.nil?
    IP.coerce("#{net.v6prefix}:#{v6_hostpart}/64")
  end

  def addresses
    net = Network.find_by!(:name => "admin")
    res = network_allocations.where(network_id: net.id).map do |a|
      a.address
    end
    res.sort
  end

  def address
    addresses.detect{|a|a.reachable?}
  end

  def url_address
    res = address
    (res.v6? ? "[#{res.addr}]" : res.addr).to_s
  end

  #
  # Helper function to test admin without calling admin. Style-thing.
  #
  def is_admin?
    admin
  end

  def virtual?
    virtual = [ "KVM", "VMware Virtual Platform", "VMWare Virtual Platform", "VirtualBox" ]
    virtual.include? get_attrib('hardware')
  end

  # retrieves the Attrib from Attrib
  def get_attrib(attrib)
    Attrib.get(attrib, self, :discovery) rescue nil
  end

  def active_node_roles
    NodeRole.on_node(self).in_state(NodeRole::ACTIVE).committed.order("cohort ASC")
  end

  def all_active_data
    dres = {}
    res = {}
    Node.transaction(read_only: true) do
      active_node_roles.each do |nr|
        dres.deep_merge!(nr.deployment_data)
        res.deep_merge!(nr.all_parent_data)
      end
    end
    dres.deep_merge(res)
  end

  def method_missing(m,*args,&block)
    method = m.to_s
    if method.starts_with? "attrib_"
      return get_attrib method[7..-1]
    else
      super
    end
  end

  def <=>(other)
    # use Array#<=> to compare the attributes
    [self.order, self.name] <=> [other.order, other.name]
  end

  def group
    groups.first
  end

  def group=(group)
    Group.transaction do
      db_group = group.is_a?(Group) ? group : Group.find_or_create_by_name({'name' => group, 'description' => group, 'category' => 'ui'})
      if db_group
        category = db_group.category
        groups.each { |g| g.nodes.delete(self) if g.category.eql?(category) }
        groups << db_group unless db_group.nodes.include? self
      end
    end
  end

  def hint_update(val)
    Node.transaction do
      self.hint = self.hint.deep_merge(val)
      save!
    end
  end

  def discovery_merge(val)
    Node.transaction do
      self.discovery = self.discovery.merge(val)
      save!
    end
  end

  def discovery_update(val)
    Node.transaction do
      self.discovery = self.discovery.deep_merge(val)
      save!
    end
  end

  def reboot
    update!(alive: false)
    ssh("reboot")
  end
  
  def debug
    Node.transaction do
      reload
      update!(alive: true,
              bootenv: "sledgehammer",
              target: Role.find_by!(:name => "crowbar-managed-node"))
    end
    reboot
  end

  def undebug
    Node.transaction do
      reload
      update!(alive: false,
              bootenv: "local",
              target: nil)
    end
    reboot
  end

  def commit!
    Node.transaction do
      reload
      update!(available: true)
      node_roles.in_state(NodeRole::PROPOSED).order("cohort ASC").each do |nr|
        nr.commit!
      end
    end
  end

  def redeploy!
    Node.transaction do
      reload
      update!(bootenv: "sledgehammer")
      node_roles.update_all(run_count: 0, state: NodeRole::PROPOSED)
    end
    reboot
    commit!
  end

  def target
    return target_role
  end
  # Set the annealer target for this node, which will restrict the annealer
  # to considering the noderole for this role bound to this node and its parents
  # for converging.  If nil is passed, then all the noderoles are marked as available.
  def target=(r)
    Node.transaction do
      reload
      if r.nil?
        old_alive = self.alive
        self.save!
        node_roles.each do |nr|
          nr.available = true
        end
        self.target_role_id = nil
        self.alive = old_alive
        self.save!
        return self
      elsif r.kind_of?(Role) &&
          roles.member?(r) &&
          r.barclamp.name == "crowbar" &&
          r.jig.name == "noop"
        old_alive = self.alive
        self.alive = false
        self.save!
        self.target_role = r
        node_roles.each do |nr|
          nr.available = false
        end
        target_nr = self.node_roles.where(:role_id => r.id).first
        target_nr.all_parents.each do |nr|
          next unless nr.node_id == self.id
          nr.available = true
        end
        target_nr.available = true
        self.save!
        return self
      else
        raise("Cannot set target role #{r.name} for #{self.name}")
      end
    end
  end

  def alive?
    return false if alive == false
    return true unless Rails.env == "production"
    a = address
    return true if a && self.ssh("echo alive")[2].success?
    Node.transaction do
      self[:alive] = false
      save!
    end
    false
  end

  private

  def run_on(cmd)
    Rails.logger.debug("Node: #{name}: Running #{cmd}")
    out,err = '',''
    status = Open4::popen4ext(true,cmd) do |pid,stdin,stdout,stderr|
      stdin.close
      out << stdout.read
      err << stderr.read
      stdout.close
      stderr.close
    end
    [out,err,status]
  end

  def after_commit_handler
    Rails.logger.debug("Node: after_commit hook called")
    Rails.logger.info("Node: calling all role on_node_change hooks for #{name}")
    # the line belowrequires a crowbar deployment to which the status attribute is tied
    Group.transaction do
      if groups.count == 0
        groups << Group.find_or_create_by(name: 'not_set',
                                          description: I18n.t('not_set', :default=>'Not Set'))
      end
    end
    # We only call on_node_change when the node is available to prevent Crowbar
    # from noticing changes it should not notice yet.
    Role.all_cohorts.each do |r|
      Rails.logger.debug("Node: Calling #{r.name} on_node_change for #{self.name}")
      r.on_node_change(self)
    end if available?
    if alive && available && node_roles.runnable.count > 0
      Rails.logger.info("Node: #{name} is alive and available, kicking the annealer.")
      Run.run!
    end
    unless alive?
      Rails.logger.info("Node: #{name} is not alive, deactivating noderoles on this node.")
      NodeRole.transaction do
        node_roles.order("cohort ASC").each do |nr|
          nr.deactivate
        end
      end
    end
  end

  # make sure some safe values are set for the node
  def default_population
    self.admin = true if Node.admin.count == 0    # first node, needs to be admin
    self.name = self.name.downcase
    self.alias ||= self.name.split(".")[0]
    self.deployment ||= Deployment.system
  end

  # Call the on_node_delete hooks.
  def on_destroy_hooks
    # do the low cohorts last
    Rails.logger.info("Node: calling all role on_node_delete hooks for #{name}")
    Role.all_cohorts_desc.each do |r|
      begin
        Rails.logger.info("Node: Calling #{r.name} on_node_delete for #{self.name}")
        r.on_node_delete(self)
      rescue Exception => e
        Rails.logger.error "node #{name} attempting to cleanup role #{r.name} failed with #{e.message}"
      end
    end
  end

  def on_create_hooks
    # Call all role on_node_create hooks with ourself.
    # These should happen synchronously.
    # do the low cohorts first
    Rails.logger.info("Node: calling all role on_node_create hooks for #{name}")
    Role.all_cohorts.each do |r|
      Rails.logger.info("Node: Calling #{r.name} on_node_create for #{self.name}")
      r.on_node_create(self)
    end
  end

end
