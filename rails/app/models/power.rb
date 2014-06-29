# Copyright 2014 Victor Lowther
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

# This class encapsulates everything we can do w.r.t power state managment
# on a node via IPMI
class Power
  def self.probe(node)
    false
  end

  # This is mainly for the subclasses.  They shold not have to override this.
  def self.power_methods
    self.instance_methods - self.superclass.instance_methods
  end

  def initialize(node)
    raise "Must initialize a power manager with a node!" unless node.kind_of?(Node)
    @node = node
    @actions = {}
    return unless self.class == Power
    mgrs = Hash.new
    # Find all the subclasses of Power in our namespace that are applicable to
    # a given node.
    Power.constants.each do |mgr|
      klass = Power.const_get(mgr)
      next unless klass.respond_to?(:superclass) &&
        (klass.superclass == Power) &&
        klass.respond_to?(:probe) &&
        klass.probe(node) &&
        klass.respond_to?(:priority)
      # Bucketize the found power managers based on their self-reported priority
      mgrs[klass.priority] ||= []
      mgrs[klass.priority] << klass.new(node)
    end
    # Build a hash of power methods applicable to the given node based on priority.
    mgrs.keys.sort.each do |k|
      mgrs[k].each do |mgr|
        mgr.class.power_methods.each do |m|
          @actions[m]=mgr
        end
      end
    end
  end

  # Return an array of power actions applicable to the node we were created for.
  def actions
    @actions.keys
  end

  def managers
    res={}
    @actions.values.uniq.each do |mgr|
      res[mgr.class] = mgr
    end
    res
  end

  def method_missing(meth,*args,&block)
    if @actions[meth]
      return @actions[meth].send(meth,*args,&block)
    else
      raise "Power control method #{meth.to_s} not valid for node #{@node.name}"
    end
  end

end

class Power::SSH < Power

  # For now, assume that the SSH power manager is always applicable.
  # This may change if we start having non-Linux nodes.
  def self.probe(node)
    true
  end

  # The SSH power manager has lowest priority
  def self.priority
    0
  end

  # and it only allows you to reboot a node via its "reboot" command
  def reboot
    @node.update!(alive: false)
    @node.ssh("reboot")
  end

end
