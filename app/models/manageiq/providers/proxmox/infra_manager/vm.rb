class ManageIQ::Providers::Proxmox::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  supports :terminate
  supports :reboot_guest
  supports :reset
  supports :suspend
  supports :start
  supports :stop
  supports :shutdown_guest

  def raw_start
    with_provider_connection do |connection|
      connection.post("/nodes/#{host.ems_ref}/qemu/#{ems_ref}/status/start")
    end
    self.update!(:raw_power_state => 'running')
  end

  def raw_stop
    with_provider_connection do |connection|
      connection.post("/nodes/#{host.ems_ref}/qemu/#{ems_ref}/status/stop")
    end
    self.update!(:raw_power_state => 'stopped')
  end

  def raw_suspend
    with_provider_connection do |connection|
      connection.post("/nodes/#{host.ems_ref}/qemu/#{ems_ref}/status/suspend")
    end
    self.update!(:raw_power_state => 'paused')
  end

  def raw_reboot_guest
    with_provider_connection do |connection|
      connection.post("/nodes/#{host.ems_ref}/qemu/#{ems_ref}/status/reboot")
    end
  end

  def raw_reset
    with_provider_connection do |connection|
      connection.post("/nodes/#{host.ems_ref}/qemu/#{ems_ref}/status/reset")
    end
  end

  def raw_shutdown_guest
    with_provider_connection do |connection|
      connection.post("/nodes/#{host.ems_ref}/qemu/#{ems_ref}/status/shutdown")
    end
    self.update!(:raw_power_state => 'stopped')
  end
end
