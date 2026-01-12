class ManageIQ::Providers::Proxmox::InfraManager::Provision < MiqProvision
  include Cloning

  def destination_type
    "Vm"
  end

  def with_provider_destination
    return if destination.nil?
    destination.with_provider_connection { |connection| yield connection }
  end
end

