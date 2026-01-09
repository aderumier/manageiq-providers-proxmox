class ManageIQ::Providers::Proxmox::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  supports :terminate
  supports :reboot_guest
  supports :reset
  supports :suspend
  supports :start
  
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.get("nodes/#{host.name}/qemu/#{ems_ref}/status/current")
  end

  def raw_start
    with_provider_connection do |connection|
      connection.post("nodes/#{host.name}/qemu/#{ems_ref}/status/start")
    end
    self.update!(:raw_power_state => "running")
  end

  def raw_stop
    with_provider_connection do |connection|
      connection.post("nodes/#{host.name}/qemu/#{ems_ref}/status/stop")
    end
    self.update!(:raw_power_state => "stopped")
  end

  def raw_suspend
    with_provider_connection do |connection|
      connection.post("nodes/#{host.name}/qemu/#{ems_ref}/status/suspend")
    end
    self.update!(:raw_power_state => "suspended")
  end

  def raw_reboot_guest
    with_provider_connection do |connection|
      connection.post("nodes/#{host.name}/qemu/#{ems_ref}/status/reboot")
    end
  end

  def raw_reset
    with_provider_connection do |connection|
      connection.post("nodes/#{host.name}/qemu/#{ems_ref}/status/reset")
    end
  end

  def raw_destroy
    with_provider_connection do |connection|
      connection.delete("nodes/#{host.name}/qemu/#{ems_ref}")
    end
    self.update!(:raw_power_state => "terminated")
  end

  private

  def with_provider_connection(&block)
    connection = ext_management_system.connect
    yield connection
  ensure
    connection&.logout if connection.respond_to?(:logout)
  end
end
