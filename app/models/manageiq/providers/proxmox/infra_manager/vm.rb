class ManageIQ::Providers::Proxmox::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  supports :terminate
  supports :reboot_guest
  supports :reset
  supports :suspend
  supports :start
  supports :stop
  supports :shutdown_guest

  POWER_STATES = {
    'running'   => 'on',
    'stopped'   => 'off',
    'paused'    => 'paused',
    'suspended' => 'suspended'
  }.freeze

  def self.calculate_power_state(raw_power_state)
    POWER_STATES[raw_power_state] || super
  end

  def raw_start
    with_provider_connection do |connection|
      location = get_vm_location(connection, ems_ref)
      connection.post("nodes/#{location[:node]}/#{location[:type]}/#{ems_ref}/status/start")
    end
    self.update!(:raw_power_state => 'running')
  end

  def raw_stop
    with_provider_connection do |connection|
      location = get_vm_location(connection, ems_ref)
      connection.post("nodes/#{location[:node]}/#{location[:type]}/#{ems_ref}/status/stop")
    end
    self.update!(:raw_power_state => 'stopped')
  end

  def raw_suspend
    with_provider_connection do |connection|
      location = get_vm_location(connection, ems_ref)
      connection.post("nodes/#{location[:node]}/#{location[:type]}/#{ems_ref}/status/suspend")
    end
    self.update!(:raw_power_state => 'paused')
  end

  def raw_reboot_guest
    with_provider_connection do |connection|
      location = get_vm_location(connection, ems_ref)
      connection.post("nodes/#{location[:node]}/#{location[:type]}/#{ems_ref}/status/reboot")
    end
  end

  def raw_reset
    with_provider_connection do |connection|
      location = get_vm_location(connection, ems_ref)
      connection.post("nodes/#{location[:node]}/#{location[:type]}/#{ems_ref}/status/reset")
    end
  end

  def raw_shutdown_guest
    with_provider_connection do |connection|
      location = get_vm_location(connection, ems_ref)
      connection.post("nodes/#{location[:node]}/#{location[:type]}/#{ems_ref}/status/shutdown")
    end
    self.update!(:raw_power_state => 'stopped')
  end

  private

  def get_vm_location(connection, vmid)
    # Find the VM in cluster resources to get its location
    resources = connection.cluster.resources
    vm_resource = resources.find { |r| r['vmid'].to_s == vmid.to_s }
    
    unless vm_resource
      raise "VM with vmid #{vmid} not found in cluster resources"
    end

    {
      node: vm_resource['node'],
      type: vm_resource['type'] # 'qemu' or 'lxc'
    }
  end
end
