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
