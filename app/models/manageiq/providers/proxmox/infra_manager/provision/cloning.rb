module ManageIQ::Providers::Proxmox::InfraManager::Provision::Cloning
  def do_clone_task_check(clone_task_upid)
    source.ext_management_system.with_provider_connection do |connection|
      begin
        # Proxmox uses UPID (Unique Process ID) for task tracking
        # Format: UPID:node:task_id:user:type:pid:starttime:extratype:status
        # Use wait_for_task to wait for clone completion (cloning can be long)
        # Use a reasonable timeout - cloning large VMs can take 10+ minutes
        connection.cluster.wait_for_task(clone_task_upid, 1800) # 30 minutes timeout
        
        # Task completed successfully - try to find the new VM
        new_vm = find_destination_in_vmdb
        unless new_vm
          # Refresh inventory to ensure new VM is available
          source.ext_management_system.refresh_ems
          new_vm = find_destination_in_vmdb
        end
        
        if new_vm
          phase_context[:new_vm_ems_ref] = new_vm.ems_ref
          phase_context[:clone_vm_task_completion_time] = Time.now.to_s
          
          # Perform migration if needed (clone always happens on source node)
          if phase_context[:migration_needed]
            migrate_vm_to_destination(new_vm)
          end
          
          return true
        else
          return false, "New VM not found after clone completion"
        end
      rescue => err
        # Check if task failed
        task_info = connection.cluster.get_task_status(clone_task_upid)
        if task_info && task_info['status'] == 'stopped' && task_info['exitstatus'] != 'OK'
          raise "VM Clone Failed: #{task_info['exitstatus']}"
        end
        
        # If task has completed and been removed, try to find destination
        new_vm = find_destination_in_vmdb
        if new_vm
          phase_context[:new_vm_ems_ref] = new_vm.ems_ref
          phase_context[:clone_vm_task_completion_time] = Time.now.to_s
          return true
        end
        
        # Re-raise if it's a timeout or other error
        raise err
      end
    end
  end

  def find_destination_in_vmdb
    # Find the new VM by checking for the expected VM ID
    # In Proxmox, ems_ref is the vmid
    expected_vmid = phase_context[:new_vm_ems_ref]
    return nil unless expected_vmid
    
    source.ext_management_system.vms_and_templates.find_by(:ems_ref => expected_vmid.to_s)
  end

  def prepare_for_clone_task
    raise MiqException::MiqProvisionError, "Provision Request's Destination VM Name=[#{dest_name}] cannot be blank" if dest_name.blank?
    
    # Check if VM with same name already exists
    existing_vm = source.ext_management_system.vms.where(:name => dest_name).first
    raise MiqException::MiqProvisionError, "A VM with name: [#{dest_name}] already exists" if existing_vm

    # Parse source location (format: "node/type/vmid")
    source_location_parts = source.location.split('/')
    source_node = source_location_parts[0]

    # Get destination node (default to source node if not specified)
    dest_node = dest_host&.ems_ref || source_node

    # Get next available VM ID if not specified
    # Note: VM ID is cluster-wide, so we can use any node to get next ID
    new_vmid = get_option(:new_vm_ems_ref) || get_next_vmid(source_node)
    phase_context[:new_vm_ems_ref] = new_vmid.to_s
    phase_context[:source_node] = source_node
    phase_context[:dest_node] = dest_node
    phase_context[:migration_needed] = (source_node != dest_node)

    clone_options = {
      :node            => dest_node,
      :source_location => source.location,
      :new_vmid        => new_vmid,
      :name            => dest_name,
      :full            => get_option(:full_clone).to_s != 'false' # Default to full clone
    }

    clone_options
  end

  def get_next_vmid(node)
    source.ext_management_system.with_provider_connection do |connection|
      result = connection.get("cluster/nextid")
      result.to_i
    end
  end

  def log_clone_options(clone_options)
    _log.info("Provisioning [#{source.name}] to [#{clone_options[:name]}]")
    _log.info("Source Template:            [#{source.name}] (#{source.ems_ref})")
    _log.info("Source Location:            [#{clone_options[:source_location]}]")
    _log.info("Destination VM Name:        [#{clone_options[:name]}]")
    _log.info("Clone will execute on:      Source node (clones always happen on source node)")
    _log.info("Destination Node:           [#{clone_options[:node]}]")
    _log.info("Migration needed:           [#{phase_context[:migration_needed]}]")
    _log.info("New VM ID:                  [#{clone_options[:new_vmid]}]")
    _log.info("Full Clone:                 [#{clone_options[:full]}]")
  end

  def start_clone(clone_options)
    log_clone_options(clone_options)
    
    upid = clone_vm(clone_options)
    _log.info("Clone task started for [#{clone_options[:name]}] with UPID: #{upid}")
    upid
  end

  def clone_vm(clone_options)
    source.ext_management_system.with_provider_connection do |connection|
      # Proxmox clone API: POST /nodes/{location}/clone
      # Note: Clone always happens on the source node (where the template/VM is located)
      # If destination node differs, migration should be performed after clone completes
      # Parameters: newid, name, full (0 or 1)
      clone_path = "nodes/#{clone_options[:source_location]}/clone"
      
      clone_params = {
        :newid => clone_options[:new_vmid],
        :name  => clone_options[:name],
        :full  => clone_options[:full] ? 1 : 0
      }
      
      # Proxmox clone returns UPID (task ID) string
      result = connection.post(clone_path, clone_params)
      
      # Handle response - ProxmoxClient.post returns result['data'], which should be the UPID string
      upid = nil
      if result.is_a?(String) && result.start_with?('UPID:')
        upid = result
      elsif result.is_a?(Hash)
        upid = result['upid'] || result['data']
      else
        raise "Unexpected clone response format: #{result.inspect}"
      end
      
      raise "Failed to get UPID from clone response" unless upid
      
      upid
    end
  end

  def migrate_vm_to_destination(vm)
    source_node = phase_context[:source_node]
    dest_node = phase_context[:dest_node]
    
    return unless source_node && dest_node && source_node != dest_node
    
    _log.info("Migrating VM #{vm.ems_ref} from node #{source_node} to node #{dest_node}")
    
    source.ext_management_system.with_provider_connection do |connection|
      # Proxmox migration API: POST /nodes/{location}/migrate
      # Parameters: target (destination node), with-local-disks (keep local disks)
      # Note: After clone, VM is always stopped, so we use offline migration
      
      # Get current VM location (should be on source node after clone)
      # Reload VM to ensure we have the latest location
      vm.reload
      current_location = vm.location
      
      unless current_location
        raise "Cannot migrate: VM location not available"
      end
      
      migrate_path = "nodes/#{current_location}/migrate"
      
      migrate_params = {
        :target => dest_node
      }
      
      # Proxmox migration returns UPID (task ID) string
      result = connection.post(migrate_path, migrate_params)
      
      # Handle response
      upid = nil
      if result.is_a?(String) && result.start_with?('UPID:')
        upid = result
      elsif result.is_a?(Hash)
        upid = result['upid'] || result['data']
      else
        raise "Unexpected migration response format: #{result.inspect}"
      end
      
      raise "Failed to get UPID from migration response" unless upid
      
      _log.info("Migration task started with UPID: #{upid}")
      
      # Wait for migration to complete
      # Migration is typically fast (few seconds) for stopped VMs
      connection.cluster.wait_for_task(upid, 10) # 10 seconds timeout for migration
      
      _log.info("Migration completed successfully")
      
      # Refresh inventory to update VM location
      source.ext_management_system.refresh_ems
    end
  rescue => err
    _log.error("Migration failed: #{err.message}")
    raise "VM Migration Failed: #{err.message}"
  end
end

