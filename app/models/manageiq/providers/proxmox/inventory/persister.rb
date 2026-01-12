class ManageIQ::Providers::Proxmox::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  def initialize_inventory_collections
    super

    add_collection(infra, :clusters)
    add_collection(infra, :hosts)
    add_collection(infra, :host_hardwares)
    add_collection(infra, :hardwares)
    add_collection(infra, :storages)
    add_collection(infra, :vms)
    add_collection(infra, :snapshots)
  end
end
