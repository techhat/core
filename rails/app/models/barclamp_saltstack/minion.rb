

class BarclampSaltstack::Minion < Role
  def on_todo(nr)
    # return if we have data
    n = Attrib.get("saltstack-minion_name", nr)
    return if n

    Attrib.set("saltstack-minion_name", nr, nr.node.name, :system)
  end

  #
  # Once active, we should update the master to accept our key
  #
  def on_active(nr)
    the_name = nr.node.name
    the_key = Attrib.get("saltstack-minion_public_key", nr)

    Rails.logger.error("saltstack-minion: bad key for #{the_name}") unless the_key

    # Find the_masters
    the_masters = []
    master_role = Role.find_by(name: 'saltstack-master')
    master_role.node_roles.each do |mnr|
      the_masters << mnr if (mnr.deployment == nr.deployment)
    end

    if the_masters.empty?
      Rails.logger.info("saltstack-minion: No master to update #{the_name}")
      return
    end

    # Update the id/key pair in the key node role
    the_masters.each do |the_master_nr|
      queue_it = false
      sd = Attrib.get("saltstack-master_keys", the_master_nr)
      sd = {} unless sd
      k = (sd[the_name] rescue nil)
      if k != the_key
        sd[the_name] = the_key
        Attrib.set("saltstack-master_keys", the_master_nr, sd, :system)
        queue_it = true
      end 

      if queue_it
        Rails.logger.info("saltstack-minion: update #{the_master_nr} with my key: #{the_name} #{the_key}")
      else
        Rails.logger.debug("saltstack-minion: already has key #{the_master_nr} for #{the_name}")
      end

      # Run the node role if we changed it
      Run.enqueue(the_master_nr) if queue_it
    end
  end

end

