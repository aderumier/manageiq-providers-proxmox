class ManageIQ::Providers::Proxmox::InfraManager::Vm < ::VmOrTemplate
    supports :terminate
    supports :reboot_guest
    supports :reset
    supports :suspend
    supports :start
    supports :stop

    def provider_object(connection = nil)
      connection ||= ext_management_system.connect
      connection
    end

    def raw_start
      with_provider_connection do |connection|
        start_vm(connection)
      end
      
      self.update!(:raw_power_state => "running")
    end

    def raw_stop
      with_provider_connection do |connection|
        stop_vm(connection)
      end
      
      self.update!(:raw_power_state => "stopped")
    end

    def raw_suspend
      with_provider_connection do |connection|
        suspend_vm(connection)
      end
      
      self.update!(:raw_power_state => "suspended")
    end

    def raw_reboot_guest
      with_provider_connection do |connection|
        reboot_vm(connection)
      end
    end

    private

    def start_vm(connection)
      node = hardware.try(:host).try(:name) || "pve"
      vmid = ems_ref
      
      RestClient::Request.execute(
        method: :post,
        url: "#{connection[:url]}/nodes/#{node}/qemu/#{vmid}/status/start",
        headers: {
          'CSRFPreventionToken' => connection[:csrf_token],
          'Cookie' => "PVEAuthCookie=#{connection[:ticket]}"
        },
        verify_ssl: false
      )
    end

    def stop_vm(connection)
      node = hardware.try(:host).try(:name) || "pve"
      vmid = ems_ref
      
      RestClient::Request.execute(
        method: :post,
        url: "#{connection[:url]}/nodes/#{node}/qemu/#{vmid}/status/stop",
        headers: {
          'CSRFPreventionToken' => connection[:csrf_token],
          'Cookie' => "PVEAuthCookie=#{connection[:ticket]}"
        },
        verify_ssl: false
      )
    end

    def suspend_vm(connection)
      node = hardware.try(:host).try(:name) || "pve"
      vmid = ems_ref
      
      RestClient::Request.execute(
        method: :post,
        url: "#{connection[:url]}/nodes/#{node}/qemu/#{vmid}/status/suspend",
        headers: {
          'CSRFPreventionToken' => connection[:csrf_token],
          'Cookie' => "PVEAuthCookie=#{connection[:ticket]}"
        },
        verify_ssl: false
      )
    end

    def reboot_vm(connection)
      node = hardware.try(:host).try(:name) || "pve"
      vmid = ems_ref
      
      RestClient::Request.execute(
        method: :post,
        url: "#{connection[:url]}/nodes/#{node}/qemu/#{vmid}/status/reboot",
        headers: {
          'CSRFPreventionToken' => connection[:csrf_token],
          'Cookie' => "PVEAuthCookie=#{connection[:ticket]}"
        },
        verify_ssl: false
      )
    end
  end
