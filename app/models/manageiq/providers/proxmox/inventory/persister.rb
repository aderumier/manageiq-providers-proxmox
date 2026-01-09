# app/models/manageiq/providers/proxmox/inventory/persister.rb
module ManageIQ::Providers::Proxmox
  class Inventory::Persister < ManageIQ::Providers::Inventory::Persister
    def initialize(manager, target)
      super

      initialize_inventory_collections
    end

    private

    def initialize_inventory_collections
      # Hosts
      add_collection(infra, :hosts) do |builder|
        builder.add_properties(:model_class => ::ManageIQ::Providers::Proxmox::InfraManager::Host)
      end

      add_collection(infra, :hardwares) do |builder|
        builder.add_properties(
          :model_class => ::Hardware,
          :manager_ref => [:vm_or_template]
        )
      end

      add_collection(infra, :operating_systems) do |builder|
        builder.add_properties(
          :model_class => ::OperatingSystem,
          :manager_ref => [:vm_or_template]
        )
      end

      # VMs
      add_collection(infra, :vms) do |builder|
        builder.add_properties(:model_class => ::ManageIQ::Providers::Proxmox::InfraManager::Vm)
      end

      # Storages
      add_collection(infra, :storages) do |builder|
        builder.add_properties(:model_class => ::ManageIQ::Providers::Proxmox::InfraManager::Storage)
      end
    end
  end
end
