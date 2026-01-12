class ManageIQ::Providers::Proxmox::Inventory::Parser::InfraManager < ManageIQ::Providers::Proxmox::Inventory::Parser
    def parse
      puts "=== Starting parse ==="
      clusters
      hosts
      vms
      storages
      puts "=== Parse completed ==="
    end

    private

    def clusters
      puts "Creating default cluster..."
      persister.clusters.build(
        :ems_ref => 'default',
        :uid_ems => 'default',
        :name    => 'Default Cluster'
      )
    end

    def hosts
      puts "Parsing #{collector.nodes.size} hosts..."
      collector.nodes.each do |node_data|
        puts "  - Host: #{node_data['node']}"
        host = persister.hosts.build(
          :ems_ref          => node_data['node'],
          :name             => node_data['node'],
          :hostname         => node_data['node'],
          :ipaddress        => node_data['ip'],
          :vmm_vendor       => 'unknown',
          :vmm_product      => 'Proxmox VE',
          :power_state      => node_data['status'] == 'online' ? 'on' : 'off',
          :connection_state => 'connected',
          :uid_ems          => node_data['node'],
          :ems_cluster      => persister.clusters.lazy_find('default')
        )

        persister.host_hardwares.build(
          :host             => host,
          :cpu_total_cores  => node_data['maxcpu'],
          :memory_mb        => node_data['maxmem'] ? (node_data['maxmem'] / 1.megabyte).to_i : nil
        )
      end
    end
    

  def vms
    puts "Parsing #{collector.vms.size} VMs..."
    collector.vms.each do |vm_data|
      puts "  - VM: #{vm_data['name']} (#{vm_data['vmid']})"

      # Calculer le power_state à partir du statut Proxmox
	#      raw_state = vm_data['status'].to_s.downcase

      # Créer le hash d'attributs
      vm_attributes = {
        :ems_ref          => vm_data['vmid'].to_s,
        :uid_ems          => vm_data['vmid'].to_s,
        :name             => vm_data['name'] || "VM-#{vm_data['vmid']}",
        :vendor           => 'unknown',
        :raw_power_state  => vm_data['status'].to_s.downcase,
        :connection_state => 'connected',
        :location         => "#{vm_data['node']}/#{vm_data['type']}/#{vm_data['vmid']}",
        :host             => persister.hosts.lazy_find(vm_data['node']),
        :ems_cluster      => persister.clusters.lazy_find('default'),
        :template         => vm_data['template'] == 1
      }

      # --- LIGNE DE DÉBOGAGE ---
      puts "--- DEBUG VM HASH: #{vm_attributes.inspect}"
      # --- FIN DE LA LIGNE DE DÉBOGAGE ---

      vm = persister.vms.build(vm_attributes)

      persister.hardwares.build(
        :vm_or_template   => vm,
        :cpu_total_cores  => vm_data['maxcpu'] || 1,
        :memory_mb        => vm_data['maxmem'] ? (vm_data['maxmem'] / 1.megabyte).to_i : nil
      )

      # Parse snapshots for this VM
      location = "#{vm_data['node']}/#{vm_data['type']}/#{vm_data['vmid']}"
      snapshots(vm, vm_data, location)
    end
  end

  def snapshots(persister_vm, vm_data, location)
    return if vm_data['template'] == 1 # Templates don't have snapshots
    
    snapshots_list = collector.snapshots_for_vm(location)
    return if snapshots_list.blank?
    
    # Proxmox snapshots have parent references, we need to build a tree
    # We'll use the snapshot name as uid_ems since it's unique per VM
    
    # Build a map of snapshot names to snapshot data for parent lookup
    snapshots_map = {}
    snapshots_list.each do |snapshot|
      snap_name = snapshot['name']
      snapshots_map[snap_name] = snapshot
    end
    
    # Check if snapshots are empty (only "current" snapshot without parent)
    current_snapshot = snapshots_map['current']
    if snapshots_list.size == 1 && current_snapshot && current_snapshot['parent'].blank?
      return # No real snapshots, only the current state marker
    end
    
    # Find the "current" snapshot and determine which snapshot is current
    # The parent of "current" is the active snapshot (current=true)
    current_snapshot_name = nil
    if current_snapshot && current_snapshot['parent']
      current_snapshot_name = current_snapshot['parent']
    end
    
    # Build parent relationships
    snapshots_list.each do |snapshot|
      snap_name = snapshot['name']
      next if snap_name == 'current' # Skip 'current' snapshot (it's not a real snapshot)
      
      parent_name = snapshot['parent']
      
      # Use parent name as parent_uid
      parent_uid = parent_name
      
      # Mark snapshot as current if it's the parent of "current" snapshot
      is_current = (snap_name == current_snapshot_name)
      
      persister.snapshots.find_or_build(:uid => snap_name).assign_attributes(
        :uid_ems        => snap_name,
        :uid            => snap_name,
        :parent_uid     => parent_uid,
        :parent         => parent_uid ? persister.snapshots.lazy_find(parent_uid) : nil,
        :name           => snapshot['name'] || '',
        :description    => snapshot['description'] || '',
        :create_time    => Time.at(snapshot['snaptime'].to_i).utc,
        :current        => is_current,
        :vm_or_template => persister_vm,
        :total_size     => snapshot['size'] || 0
      )
    end
  end

    def storages
      puts "Parsing #{collector.storages.size} storages..."
      collector.storages.each do |storage_data|
        puts "  - Storage: #{storage_data['storage']}"
        persister.storages.build(
          :ems_ref      => storage_data['storage'],
          :name         => storage_data['storage'],
          :store_type   => storage_data['plugintype'] || storage_data['content'],
          :total_space  => storage_data['maxdisk'],
          :free_space   => (storage_data['maxdisk'] || 0) - (storage_data['disk'] || 0)
        )
      end
    end
  end
