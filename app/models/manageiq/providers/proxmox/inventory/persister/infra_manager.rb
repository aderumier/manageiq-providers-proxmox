class ManageIQ::Providers::Proxmox::Inventory::Persister::InfraManager < ManageIQ::Providers::Proxmox::Inventory::Persister
  def initialize_inventory_collections
    add_collection(infra, :clusters)
    add_collection(infra, :hosts)
    add_collection(infra, :host_hardwares)
    add_collection(infra, :storages)
    add_collection(infra, :host_storages)
    add_collection(infra, :vms)
    add_collection(infra, :hardwares)
  end
end
