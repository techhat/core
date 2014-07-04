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

require 'json'

class NodeRole < ActiveRecord::Base

  after_commit :run_hooks, on: [:update, :create]
  validate :role_is_bindable, on: :create
  validate :validate_conflicts, on: :create
  after_create :bind_needed_parents

  belongs_to      :node
  belongs_to      :role
  belongs_to      :deployment
  has_one         :barclamp,          :through => :role
  has_many        :attribs,           :through => :role
  has_many        :runs,              :dependent => :destroy

  # find other node-roles in this deployment using their role or node
  scope           :all_by_state,      ->(state) { where(['node_roles.state=?', state]) }
  # A node is runnable if:
  # It is in TODO.
  # It is in a committed deployment.
  scope           :committed,         -> { joins(:deployment).where('deployments.state' => Deployment::COMMITTED).readonly(false) }
  scope           :deactivatable,     -> { where(:state => [ACTIVE, TRANSITION, ERROR]) }
  scope           :in_state,          ->(state) { where('node_roles.state' => state) }
  scope           :not_in_state,      ->(state) { where(['node_roles.state != ?',state]) }
  scope           :available,         -> { where(:available => true) }
  scope           :runnable,          -> { available.committed.in_state(NodeRole::TODO).joins(:node).where('nodes.alive' => true, 'nodes.available' => true).joins(:role).joins('inner join jigs on jigs.name = roles.jig_name').readonly(false).where(['node_roles.node_id not in (select node_roles.node_id from node_roles where node_roles.state in (?, ?))',TRANSITION,ERROR]) }
  scope           :committed_by_node, ->(node) { where(['state<>? AND state<>? AND node_id=?', NodeRole::PROPOSED, NodeRole::ACTIVE, node.id])}
  scope           :in_deployment,       ->(deployment) { where(:deployment_id => deployment.id) }
  scope           :with_role,         ->(r) { where(:role_id => r.id) }
  scope           :on_node,           ->(n) { where(:node_id => n.id) }
  scope           :peers_by_state,    ->(ss,state) { in_deployment(ss).in_state(state) }
  scope           :peers_by_role,     ->(ss,role)  { in_deployment(ss).with_role(role) }
  scope           :peers_by_node,     ->(ss,node)  { in_deployment(ss).on_node(node) }
  scope           :peers_by_node_and_role,     ->(s,n,r) { peers_by_node(s,n).with_role(r) }
  scope           :deployment_node_role,    ->(s,n,r) { where(['deployment_id=? AND node_id=? AND role_id=?', s.id, n.id, r.id]) }

  # make sure that new node-roles have require upstreams
  # validate        :deployable,        :if => :deployable?
  # node_role_pcms maps parent noderoles to child noderoles.
  has_and_belongs_to_many(:parents,
                          :class_name => "NodeRole",
                          :join_table => "node_role_pcms",
                          :foreign_key => "child_id",
                          :association_foreign_key => "parent_id",
                          :order => "cohort DESC")
  has_and_belongs_to_many(:children,
                          :class_name => "NodeRole",
                          :join_table => "node_role_pcms",
                          :foreign_key => "parent_id",
                          :association_foreign_key => "child_id",
                          :order => "cohort ASC")
  # node_role_all_pcms is a view that expands node_role_pcms
  # to include all of the parents and children of a noderole,
  # recursively.
  has_and_belongs_to_many(:all_parents,
                          :class_name => "NodeRole",
                          :join_table => "node_role_all_pcms",
                          :foreign_key => "child_id",
                          :association_foreign_key => "parent_id",
                          :order => "cohort DESC",
                          :delete_sql => "SELECT 1")
  has_and_belongs_to_many(:all_children,
                          :class_name => "NodeRole",
                          :join_table => "node_role_all_pcms",
                          :foreign_key => "parent_id",
                          :association_foreign_key => "child_id",
                          :order => "cohort ASC",
                          :delete_sql => "SELECT 1")

  # State transitions:
  # All node roles start life in the PROPOSED state.
  # At deployment commit time, all node roles in PROPOSED that:
  #  1. Have no parent node role, or
  #  2. Have a parent in ACTIVE state
  # will be placed in TODO state, and all others will be placed in BLOCKED.
  #
  # The annealer will then find all node roles in the TODO state, set them
  # to TRANSITION, and hand them over to their appropriate jigs.
  #
  # If the operation for the node role succeeds, the jig will set the
  # node_role to ACTIVE, set all the node_role's BLOCKED children to TODO, and
  # wake up the annealer for another pass.
  #
  # If the operation for the node role fails, the jig will set the node_role to
  # ERROR, set all of its children (recursively) to BLOCKED, and no further
  # processing for that node role dependency tree will happen.

  ERROR      = -1
  ACTIVE     =  0
  TODO       =  1
  TRANSITION =  2
  BLOCKED    =  3
  PROPOSED   =  4
  STATES     = {
    ERROR => 'error',
    ACTIVE => 'active',
    TODO => 'todo',
    TRANSITION => 'transition',
    BLOCKED => 'blocked',
    PROPOSED => 'proposed'
  }

  class InvalidTransition < Exception
    def initialize(node_role,from,to,str=nil)
      @errstr = "#{node_role.name}: Invalid state transition from #{NodeRole.state_name(from)} to #{NodeRole.state_name(to)}"
      @errstr += ": #{str}" if str
    end
    def to_s
      @errstr
    end

    def to_str
      to_s
    end
  end

  class InvalidState < Exception
  end

  class MissingJig < Exception
    def initalize(nr)
      @errstr = "NodeRole #{nr.name}: Missing jig #{nr.role.jig_name}"
    end
    def to_s
      @errstr
    end
    def to_str
      to_s
    end
  end

  # lookup i18n version of state
  def state_name
    NodeRole.state_name(state)
  end

  def self.state_name(state)
    raise InvalidState.new("#{state || 'nil'} is not a valid NodeRole state!") unless state and STATES.include? state
    I18n.t(STATES[state], :scope=>'node_role.state')
  end

  def error?
    state == ERROR
  end

  def active?
    state == ACTIVE
  end

  def todo?
    state == TODO
  end

  def transition?
    state == TRANSITION
  end

  def blocked?
    state == BLOCKED
  end

  def proposed?
    state == PROPOSED
  end

  def activatable?
    (parents.count == 0) || (parents.not_in_state(ACTIVE).count == 0)
  end

  def runnable?
    node.available && node.alive && jig.active && committed_data && deployment.committed?
  end

  # convenience methods
  def name
    "#{deployment.name}: #{node.name}: #{role.name}" rescue I18n.t('unknown')
  end

  def deployment_role
    DeploymentRole.find_by(deployment_id: deployment_id,
                           role_id: role_id)
  end

  def deployment_data
    res = {}
    dr = deployment_role
    res.deep_merge!(dr.all_data)
    res.deep_merge!(dr.wall)
    res
  end

  def available
    read_attribute("available")
  end

  def available=(b)
    NodeRole.transaction do
      write_attribute("available",!!b)
      save!
    end
  end

  def add_parent(new_parent)
    NodeRole.transaction do
      return if parents.any?{|p| p.id == new_parent.id}
      if new_parent.cohort >= (self.cohort || 0)
        self.cohort = new_parent.cohort + 1
        save!
      end
      Rails.logger.info("Role: Binding parent #{new_parent.name} to #{self.name}")
      parents << new_parent
    end
  end

  def data
    proposed? ? proposed_data : committed_data
  end

  def data=(arg)
    raise I18n.t('node_role.cannot_edit_data') unless proposed?
    update!(proposed_data: arg)
  end

  def data_update(val)
    NodeRole.transaction do
      update!(proposed_data: proposed_data.deep_merge(val))
    end
  end

  def sysdata
    return role.sysdata(self) if role.respond_to?(:sysdata)
    read_attribute("sysdata")
  end

  def sysdata=(arg)
    raise("#{role.name} dynamically overwrites sysdata, cannot write to it!") if role.respond_to?(:sysdata)
    NodeRole.transaction do
      update_column("sysdata", arg)
    end
  end

  def sysdata_update(val)
    NodeRole.transaction do
      self.sysdata = self.sysdata.deep_merge(val)
    end
  end

  def wall_update(val)
    NodeRole.transaction do
      self.wall = self.wall.deep_merge(val)
      save!
    end
  end

  def all_my_data
    res = {}
    res.deep_merge!(wall)
    res.deep_merge!(sysdata)
    res.deep_merge!(data)
    res
  end

  def attrib_data
    deployment_data.deep_merge(all_my_data)
  end

  def all_deployment_data
    res = {}
    all_parents.each {|parent| res.deep_merge!(parent.deployment_data)}
    res.deep_merge(deployment_data)
  end

  def all_parent_data
    res = {}
    all_parents.each do |parent|
      next unless parent.node_id == node_id || parent.role.server
      res.deep_merge!(parent.all_my_data) end
    res
  end

  def all_data
    res = all_deployment_data
    res.deep_merge!(all_parent_data)
    res.deep_merge(all_my_data)
  end

  def all_transition_data
    dres = {}
    sysres = {}
    userres = {}
    NodeRole.transaction(read_only: true) do
      all_parents.include(:deployment_roles, :roles).each do |rent|
        dres.deep_merge!(rent.deployment_data)
        sysres.deep_merge!(rent.sysdata)
        userres.deep_merge!(rent.committed_data)
      end
      dres.deep_merge!(deployment_data)
      dres.deep_merge!(sysdata)
      dres.deep_merge!(committed_data)
    end
    dres.deep_merge(sysres).deep_merge(userres)
  end

  def rerun
    NodeRole.transaction do
      raise InvalidTransition(self,state,TODO,"Cannot rerun transition") unless error?
      write_attribute("state",TODO)
      save!
    end
  end

  def deactivate
    NodeRole.transaction do
      reload
      return if proposed?
      block_or_todo
    end
  end

  def error!
    # We can also go to ERROR pretty much any time.
    # but we silently ignore the transition if in BLOCKED
    NodeRole.transaction do
      reload
      return if blocked?
      update!(state: ERROR)
      # All children of a node_role in ERROR go to BLOCKED.
      all_children.where(["state NOT IN(?,?)",PROPOSED,TRANSITION]).update_all(state: BLOCKED)
    end
  end

  def active!
    # We can only go to ACTIVE from TRANSITION
    # but we silently ignore the transition if in BLOCKED
    NodeRole.transaction do
      update!(run_count: run_count + 1)
      if !node.alive
        block_or_todo
      else
        raise InvalidTransition.new(self,state,ACTIVE) unless transition?
        update!(state: ACTIVE)
      end
    end
    # Moving any BLOCKED noderoles to TODO will be handled in the after_commit hook.
  end

  def todo!
    # You can pretty much always go back to TODO as long as all your parents are ACTIVE
    NodeRole.transaction do
      reload
      raise InvalidTransition.new(self,state,TODO,"Not all parents are ACTIVE") unless activatable?
      update!(state: TODO)
      # Going into TODO transitions all our children into BLOCKED.
      all_children.where(["state NOT IN(?,?)",PROPOSED,TRANSITION]).update_all(state: BLOCKED)
    end
  end

  def transition!
    # We can only go to TRANSITION from TODO or ACTIVE
    NodeRole.transaction do
      reload
      unless todo? || active? || transition?
        raise InvalidTransition.new(self,state,TRANSITION)
      end
      Rails.logger.info("NodeRole: Transitioning #{name}")
      update!(state: TRANSITION, runlog: "")
    end
  end

  def block!
    # We can pretty much always go to BLOCKED.
    NodeRole.transaction do
      reload
      update!(state: BLOCKED)
      all_children.where(["state NOT IN(?,?)",PROPOSED,TRANSITION]).update_all(state: BLOCKED)
    end
  end

  def propose!
    # We can also pretty much always go into PROPOSED,
    # and it does not affect the state of our children until
    # we go back out of PRPOPSED.
    NodeRole.transaction do
      reload
      update!(state: PROPOSED)
    end
  end

  def name
   "#{deployment.name}: #{node.name}: #{role.name}" rescue I18n.t('unknown')
  end

  # Commit takes us back to TODO or BLOCKED, depending
  def commit!
    NodeRole.transaction do
      reload
      unless proposed?
        raise InvalidTransition.new(self,state,TODO,"Cannot commit! unless proposed")
      end
      return unless proposed? || blocked?
      update!(committed_data: proposed_data)
      block_or_todo
    end
  end

  # convenience methods
  def description
    role.description
  end

  def jig
    role.jig
  end

  private

  def block_or_todo
    NodeRole.transaction do
      update!(state: (activatable? ? TODO : BLOCKED))
    end
    if !node.alive && node.power.actions.member?(:on)
      node.power.on
    end
  end

  def run_hooks
    meth = "on_#{STATES[state]}".to_sym
    if proposed?
      # on_proposed only runs on initial noderole creation.
      Rails.logger.debug("NodeRole #{name}: Calling #{meth} hook.")
      role.send(meth,self)
      return
    end
    return unless previous_changes["state"]
    if deployment.committed? && available &&
        ((!role.destructive) || (run_count == self.active? ? 1 : 0))
      Rails.logger.debug("NodeRole #{name}: Calling #{meth} hook.")
      role.send(meth,self)
    end
    if todo? && runnable? && !Run.exists?(node_id: self.node_id, running: true)
      Rails.logger.info("NodeRole #{name} is runnable, kicking the annealer.")
      Run.run!
    end
    if active?
      # Immediate children of an ACTIVE node go to TODO
      NodeRole.transaction do
        children.where(state: BLOCKED).each do |c|
          Rails.logger.debug("NodeRole #{name}: testing to see if #{c.name} is runnable")
          next unless c.activatable?
          c.todo!
        end
      end
    end
  end

  def role_is_bindable
    # Check to see if there are any unresolved role_requires.
    # If there are, then this role cannot be bound.
    role = Role.find(role_id)
    unresolved = role.unresolved_requires
    unless unresolved.empty?
      errors.add(:role_id, "role #{role.name} is missing prerequisites: #{unresolved.map{|rr|rr.require}}")
    end
    # Abstract roles cannot be bound.
    errors.add(:role_id,"role #{role.name} is abstract and cannot be bound to a node") if role.abstract
    # Roles can only be added to a node of their backing jig is active.
    unless role.active?
      # if we are testing, then we're going to just skip adding and keep going
      if Jig.active('test')
        Rails.logger.info("Role: Test mode allows us to coerce role #{name} to use the 'test' jig instead of #{role.jig_name} when it is not active")
        role.jig = Jig.find_by(name: 'test')
        role.save
      else
        errors.add(:role_id, "role '#{role.name}' cannot be bound without '#{role.jig_name}' being active!")
        end
    end
  end

  def validate_conflicts
    role = Role.find(role_id)
    Node.find(node_id).node_roles.each do |nr|
      # Test to see if this role conflicts with us, or if we conflict with it.
      if role.conflicts.include?(nr.role.name) || nr.role.conflicts.include?(role.name)
        errors.add(:role, "#{role.name} cannot be bound because it conflicts with previously-bound role #{nr.role.name} on #{node.name}")
      end
      # Test to see if a previously-bound noderole provides this one.
      if nr.role.provides.include?(role.name)
        errors.add(:role, "#{role.name} cannot be bound because it is provided by previously-bound role #{nr.role.name} on #{node.name}")
      end
      # Test to see if we want to provide something that a previously-bound noderole provides.
      if role.provides.include?(nr.role.name)
        errors.add(:role, "#{role.name} cannot be bound because it tries to provide #{nr.role.name}, which is already bound on #{nr.node.name}")
      end
      # Test to see if there are overlapping provides
      overlapping = role.provides & nr.role.provides
      next if overlapping.empty?
      errors.add(:role, "#{role.name} cannot be bound because it and #{nr.role.name} both provide #{overlapping.inspect}")
    end
  end

  def bind_needed_parents
    # Bind to all the parents we need.
    role = Role.find(role_id)
    node = Node.find(node_id)
    dep = Deployment.find(deployment_id)
    role.add_to_deployment(dep)
    parent_noderoles = []
    role.parents.each do |parent|
      # If the parent we need is bound directly to this node, use it.
      tenative_parent = NodeRole.find_by(role_id: parent.id, node_id: node.id)
      # If we have a noderole bound to us that provides the parent we are looking for, use it.
      tenative_parent ||= NodeRole.find_by("node_id = ? AND role_id in
                                            (select id from roles where ? = ANY(provides))",
                                           node.id,
                                           parent.name)
      # If the parent is implicit, we must bind it now if it is not already bound
      if parent.implicit?
        tenative_parent ||= NodeRole.create!(role_id: parent.id,
                                             node_id: node.id,
                                             deployment_id: dep.id)
        parent_noderoles << tenative_parent
        next
      end
      # Otherwise, check to see if we can find an appropriate noderole in the current deployment hierarchy
      cdep = dep
      until tenative_parent || cdep.nil?
        tenative_parent = NodeRole.find_by(deployment_id: cdep.id, role_id: parent.id)
        tenative_parent ||= NodeRole.find_by("deployment_id = ? AND role_id in
                                             (select id from roles where ? = ANY(provides))",
                                             cdep.id,
                                             parent.name)
        cdep = (cdep.parent rescue nil)
      end
      # If we didn't find a tenative parent, bind it to ourselves
      # in the current deployment
      tenative_parent ||= NodeRole.create!(role_id: parent.id,
                                           node_id: node.id,
                                           deployment_id: dep.id)
      parent_noderoles << tenative_parent
    end

    parent_noderoles.each do |parent_node_role|
      parent = parent_node_role.role
      if parent.cluster
        # If the parent role has a cluster flag, then all of the found
        # parent noderoles will be bound to this one.
        NodeRole.where(deployment_id: parent_node_role.deployment_id,
                       role_id: parent_node_role.role_id) do |pnr|
          add_parent(pnr)
        end
      end
      add_parent(parent_node_role)
    end
    # If I am a new noderole binding for a cluster node, find all the children of my peers
    # and bind them too.
    if role.cluster
      NodeRole.peers_by_role(dep,role).each do |peer|
        peer.children.each do |c|
          c.add_parent(self)
          c.deactivate
          c.save!
        end
      end
    end
  end
end
