module ManageIQ::Providers::Proxmox
  class Inventory::Collector < ManageIQ::Providers::Inventory::Collector
    def initialize(manager, target)
      super
      @manager = manager
      @target = target
      @connection = manager.connect
    end

    def nodes
      @nodes ||= @connection.nodes.all
    end

    def vms
      @vms ||= collect_vms
    end

    def storages
      @storages ||= collect_storages
    end

    private

    def collect_vms
      vms = []
      nodes.each do |node|
        node_name = node['node']
        node_vms = @connection.nodes.get(node_name).qemu.all
        node_vms.each do |vm|
          vm['node'] = node_name  # Ajouter le nom du nœud à chaque VM
          vms << vm
        end
      end
      vms
    rescue => err
      _log.error("Error collecting VMs: #{err.message}")
      []
    end

    def collect_storages
      storages = []
      nodes.each do |node|
        node_name = node['node']
        node_storages = @connection.get("/nodes/#{node_name}/storage")
        storages.concat(node_storages) if node_storages
      end
      storages
    rescue => err
      _log.error("Error collecting storages: #{err.message}")
      []
    end
  end
end
