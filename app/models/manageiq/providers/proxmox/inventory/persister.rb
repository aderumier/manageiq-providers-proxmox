class ManageIQ::Providers::Proxmox::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  def initialize_inventory_collections
    super

    add_collection(infra, :clusters)
    add_collection(infra, :hosts)
    add_collection(infra, :host_hardwares)
    add_collection(infra, :hardwares)
    add_collection(infra, :storages)

    add_collection(infra, :vms) do |builder|
      builder.add_default_properties
      
      # LIGNE CORRIGÉE : Gérer le cas où :attributes est nil au départ
      existing_attributes = builder.properties[:attributes] || []
      
      builder.add_properties(
        :attributes => existing_attributes + %i[power_state]
      )
    end
  end
end
