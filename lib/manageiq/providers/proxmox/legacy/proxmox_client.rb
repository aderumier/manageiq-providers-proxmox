# lib/manageiq/providers/proxmox/legacy/proxmox_client.rb
module ManageIQ
  module Providers
    module Proxmox
      module Legacy
        class ProxmoxClient
          require 'rest-client'
          require 'json'
          require 'uri'

          attr_reader :ticket, :csrf_token

          def initialize(host, username, password, port = 8006, verify_ssl = false)
            @host = host
            @username = username
            @password = password
            @port = port
            @verify_ssl = verify_ssl
            @ticket = nil
            @csrf_token = nil
            @base_url = "https://#{@host}:#{@port}/api2/json"
            
            authenticate
          end

          def authenticate
            url = "#{@base_url}/access/ticket"
            
            response = RestClient::Request.execute(
              method: :post,
              url: url,
              payload: URI.encode_www_form({
                username: @username,
                password: @password
              }),
              headers: {
                content_type: 'application/x-www-form-urlencoded'
              },
              verify_ssl: @verify_ssl
            )

            result = JSON.parse(response.body)
            @ticket = result.dig('data', 'ticket')
            @csrf_token = result.dig('data', 'CSRFPreventionToken')

            raise "Authentication failed: no ticket received" unless @ticket
          rescue RestClient::Unauthorized => e
            raise "Authentication failed: Invalid credentials (401)"
          rescue => e
            raise "Connection error: #{e.message}"
          end

          def get(path)
            url = "#{@base_url}#{path}"
            
            response = RestClient::Request.execute(
              method: :get,
              url: url,
              headers: {
                'Cookie' => "PVEAuthCookie=#{@ticket}"
              },
              verify_ssl: @verify_ssl
            )

            JSON.parse(response.body)
          rescue => e
            raise "GET request failed for #{path}: #{e.message}"
          end

          def get_nodes
            result = get('/nodes')
            result['data'] || []
          end

          def get_vms
            nodes = get_nodes
            vms = []

            nodes.each do |node|
              node_name = node['node']
              
              # Get QEMU VMs
              qemu_vms = get("/nodes/#{node_name}/qemu")
              qemu_data = qemu_vms['data'] || []
              
              qemu_data.each do |vm|
                vm['node'] = node_name
                vm['type'] = 'qemu'
                vms << vm
              end

              # Get LXC containers
              begin
                lxc_vms = get("/nodes/#{node_name}/lxc")
                lxc_data = lxc_vms['data'] || []
                
                lxc_data.each do |vm|
                  vm['node'] = node_name
                  vm['type'] = 'lxc'
                  vms << vm
                end
              rescue => e
                # LXC might not be available on all nodes
              end
            end

            vms
          end

          def get_vm_details(node, vmid, type = 'qemu')
            result = get("/nodes/#{node}/#{type}/#{vmid}/status/current")
            result['data'] || {}
          end

          def get_storages
            result = get('/storage')
            result['data'] || []
          end

          def verify
            get_nodes
            true
          rescue => e
            false
          end
        end
      end
    end
  end
end
