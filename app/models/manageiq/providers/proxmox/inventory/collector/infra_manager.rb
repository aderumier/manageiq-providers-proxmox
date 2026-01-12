class ManageIQ::Providers::Proxmox::Inventory::Collector::InfraManager < ManageIQ::Providers::Proxmox::Inventory::Collector
  def cluster_resources
    @cluster_resources ||= begin
      _log.info("=== Fetching cluster resources via /cluster/resources ===")
      resources = connection.cluster.resources
      _log.info("Fetched #{resources&.size || 0} resources from cluster")
      resources || []
    rescue => err
      _log.error("Failed to fetch cluster resources: #{err.message}")
      _log.error(err.backtrace.join("\n"))
      []
    end
  end

  def nodes
    @nodes ||= begin
      result = cluster_resources.select { |r| r['type'] == 'node' }
      _log.info("Found #{result.size} nodes")
      result
    end
  end

  def vms
    @vms ||= begin
      result = cluster_resources.select { |r| r['type'] == 'qemu' }
      _log.info("Found #{result.size} QEMU VMs")
      result
    end
  end

  def containers
    @containers ||= begin
      result = cluster_resources.select { |r| r['type'] == 'lxc' }
      _log.info("Found #{result.size} LXC containers")
      result
    end
  end

  def storages
    @storages ||= begin
      result = cluster_resources.select { |r| r['type'] == 'storage' }
      _log.info("Found #{result.size} storages")
      result
    end
  end

  def pools
    @pools ||= begin
      result = cluster_resources.select { |r| r['type'] == 'pool' }
      _log.info("Found #{result.size} pools")
      result
    end
  end

  def snapshots_for_vm(location)
    @snapshots_cache ||= {}
    
    return @snapshots_cache[location] if @snapshots_cache.key?(location)
    
    @snapshots_cache[location] = begin
      snapshots = connection.get("nodes/#{location}/snapshot") || []
      # Handle both array and hash response
      snapshots = snapshots['data'] if snapshots.is_a?(Hash) && snapshots.key?('data')
      snapshots.is_a?(Array) ? snapshots : []
    rescue => err
      _log.debug("Failed to fetch snapshots for VM at location #{location}: #{err.message}")
      []
    end
  end
end
