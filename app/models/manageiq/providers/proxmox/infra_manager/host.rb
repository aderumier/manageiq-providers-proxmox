# app/models/manageiq/providers/proxmox/infra_manager/host.rb
class ManageIQ::Providers::Proxmox::InfraManager::Host < ::Host
  supports :refresh_ems

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection
  end

  def verify_credentials(_auth_type = nil, _options = {})
    true
  end

  # Récupérer les informations détaillées du node
  def get_node_status
    with_provider_connection do |connection|
      connection.get("/nodes/#{ems_ref}/status")
    end
  end

  # Récupérer les VMs sur ce host
  def get_vms
    with_provider_connection do |connection|
      qemu_vms = connection.get("/nodes/#{ems_ref}/qemu")
      lxc_containers = connection.get("/nodes/#{ems_ref}/lxc")
      
      {
        :qemu => qemu_vms['data'] || [],
        :lxc  => lxc_containers['data'] || []
      }
    end
  end

  # Récupérer les informations de stockage du node
  def get_storage_info
    with_provider_connection do |connection|
      connection.get("/nodes/#{ems_ref}/storage")
    end
  end

  # Récupérer les informations réseau du node
  def get_network_info
    with_provider_connection do |connection|
      connection.get("/nodes/#{ems_ref}/network")
    end
  end
end
