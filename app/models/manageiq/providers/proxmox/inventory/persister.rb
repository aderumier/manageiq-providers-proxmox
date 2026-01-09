class ManageIQ::Providers::Proxmox::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  def initialize_inventory_collections
    super

    add_collection(infra, :clusters)
    add_collection(infra, :hosts)
    add_collection(infra, :host_hardwares)

    # On modifie la collection :vms pour accepter les attributs de power_state
    add_collection(infra, :vms) do |builder|
      builder.add_properties(
        :attributes => %i[
          connection_state
          power_state
          raw_power_state
        ]
      )
    end

    add_collection(infra, :hardwares)
    add_collection(infra, :storages)
  end
end
