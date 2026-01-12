class ManageIQ::Providers::Proxmox::InfraManager::Vm
  module RemoteConsole
    def console_supported?(type)
      %w[VNC HTML5].include?(type.upcase)
    end

    def validate_remote_console_acquire_ticket(protocol, options = {})
      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} protocol not enabled for this vm") unless protocol.to_sym == :html5

      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} remote console requires the vm to be registered with a management system.") if ext_management_system.nil?

      options[:check_if_running] = true unless options.key?(:check_if_running)
      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} remote console requires the vm to be running.") if options[:check_if_running] && state != "on"
    end

    def remote_console_acquire_ticket(userid, originating_server, console_type)
      validate_remote_console_acquire_ticket(console_type)
      remote_console_acquire_ticket_impl(userid, originating_server)
    end

    def remote_console_acquire_ticket_queue(protocol, userid)
      task_opts = {
        :action => "acquiring Vm #{name} #{protocol.to_s.upcase} remote console ticket for user #{userid}",
        :userid => userid
      }

      queue_opts = {
        :class_name  => self.class.name,
        :instance_id => id,
        :method_name => 'remote_console_acquire_ticket',
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => 'ems_operations',
        :zone        => my_zone,
        :args        => [userid, MiqServer.my_server.id, protocol]
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end


    private

    def remote_console_acquire_ticket_impl(userid, originating_server)
      with_provider_connection do |connection|
        # Create VNC proxy ticket
        # POST /nodes/{location}/vncproxy with websocket=1
        # ProxmoxClient.post returns result['data'], so result should already be the data hash
        result = connection.post("nodes/#{location}/vncproxy", { :websocket => 1 })
        
        # Handle both hash response and string response (UPID)
        if result.is_a?(Hash)
          ticket = result['ticket']
          port = result['port']
        elsif result.is_a?(String)
          # If we get a string, it might be an UPID - this shouldn't happen for vncproxy
          raise "Unexpected response format from VNC proxy: #{result}"
        else
          raise "Invalid VNC proxy response: #{result.inspect}"
        end
        
        raise "Invalid VNC proxy response: missing ticket or port" unless ticket && port && port > 0
        
        # Construct websocket URL
        # Format: wss://{host}:{port}/api2/json/nodes/{location}/vncwebsocket?port={port}&vncticket={ticket}
        host = ext_management_system.address
        api_port = ext_management_system.port || 8006
        require 'uri'
        encoded_ticket = URI.encode_www_form_component(ticket)
        websocket_url = "wss://#{host}:#{api_port}/api2/json/nodes/#{location}/vncwebsocket?port=#{port}&vncticket=#{encoded_ticket}"
        
        {
          :ticket     => ticket,
          :port       => port,
          :websocket  => websocket_url,
          :protocol   => 'vnc',
          :type       => 'vnc'
        }
      end
    end

  end
end

