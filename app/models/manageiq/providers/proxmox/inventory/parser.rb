# frozen_string_literal: true

module ManageIQ::Providers::Proxmox
  class Inventory::Parser < ManageIQ::Providers::Inventory::Parser
    def initialize(collector, persister)
      @collector = collector
      @persister = persister
    end

    def parse
      _log.info("Parsing Proxmox inventory for #{manager.name}...")
      parse_hosts
      parse_vms
      parse_storages
      _log.info("Parsing complete")
      true
    end

    private

    attr_reader :collector, :persister

    def manager
      @persister.manager
    end

    def parse_hosts
      _log.info("Parsing #{collector.nodes.count} hosts...")
      collector.nodes.each do |node|
        ems_ref = node['node']
        host = persister.hosts.build(
          :ems_ref          => ems_ref,
          :uid_ems          => ems_ref,
          :name             => ems_ref,
          :hostname         => ems_ref,
          :ipaddress        => node['ip'] || manager.hostname,
          :vmm_vendor       => 'unknown',
          :vmm_product      => 'Proxmox VE',
          :vmm_version      => node['version'],
          :power_state      => node['status'] == 'online' ? 'on' : 'off',
          :connection_state => node['status'] == 'online' ? 'connected' : 'disconnected'
        )

        persister.hardwares.build(
          :vm_or_template  => host,
          :cpu_total_cores => node['maxcpu'],
          :memory_mb       => node['maxmem'] ? (node['maxmem'] / 1.megabyte).to_i : nil
        )

        persister.operating_systems.build(
          :vm_or_template => host,
          :product_name   => 'Proxmox VE',
          :version        => node['version']
        )
      end
    end

    def parse_vms
      _log.info("Parsing #{collector.vms.count} VMs...")
      collector.vms.each do |vm|
        vmid = vm['vmid'].to_s
        node  = vm['node'].to_s
        # Unique id at cluster level: use vmid as ems_ref/uid_ems
        ems_ref = vmid
        uid_ems  = ems_ref
        location = "#{node}/#{vmid}"

        # Find host by uid_ems (node name) or name
        host = persister.hosts.lazy_find(node) || persister.hosts.lazy_find(node, :uid_ems)

        vm_record = persister.vms.build(
          :ems_ref         => ems_ref,
          :uid_ems         => uid_ems,
          :name            => vm['name'] || "vm-#{vmid}",
          :location        => location,
          :raw_power_state => vm['status'],
          :connection_state=> 'connected',
          :host            => host,
          :template        => false,
          :vendor          => 'unknown'
        )

        persister.hardwares.build(
          :vm_or_template   => vm_record,
          :cpu_total_cores  => vm['cpus'],
          :memory_mb        => vm['maxmem'] ? (vm['maxmem'] / 1.megabyte).to_i : nil,
          :disk_capacity    => vm['maxdisk']
        )

        persister.operating_systems.build(
          :vm_or_template => vm_record,
          :product_name   => vm['ostype'] || 'Other'
        )
      end
    end

    def parse_storages
      _log.info("Parsing #{collector.storages.count} storages...")
      collector.storages.each do |storage|
        persister.storages.build(
          :ems_ref     => storage['storage'],
          :name        => storage['storage'],
          :store_type  => storage['type'],
          :total_space => storage['maxdisk'],
          :free_space  => storage['maxdisk'] ? storage['maxdisk'] - storage['disk'] : nil,
          :uncommitted => 0
        )
      end
    end
  end
end
