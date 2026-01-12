class ManageIQ::Providers::Proxmox::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include_concern "Operations"

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
      connection.post("nodes/#{location}/status/start")
    end
    self.update!(:raw_power_state => 'running')
  end

  def raw_stop
    with_provider_connection do |connection|
      connection.post("nodes/#{location}/status/stop")
    end
    self.update!(:raw_power_state => 'stopped')
  end

  def raw_suspend
    with_provider_connection do |connection|
      connection.post("nodes/#{location}/status/suspend")
    end
    self.update!(:raw_power_state => 'paused')
  end

  def raw_reboot_guest
    with_provider_connection do |connection|
      connection.post("nodes/#{location}/status/reboot")
    end
  end

  def raw_reset
    with_provider_connection do |connection|
      connection.post("nodes/#{location}/status/reset")
    end
  end

  def raw_shutdown_guest
    with_provider_connection do |connection|
      connection.post("nodes/#{location}/status/shutdown")
    end
    self.update!(:raw_power_state => 'stopped')
  end
end
