module ManageIQ::Providers
  class Proxmox::InfraManager < ManageIQ::Providers::InfraManager

    include ManageIQ::Providers::Proxmox::ManagerMixin
    supports :create
    supports :provisioning
    supports :refresh_new_target

    def self.ems_type
      @ems_type ||= "proxmox".freeze
    end

    def self.description
      @description ||= "Proxmox".freeze
    end

    def self.hostname_required?
      true
    end

    def self.display_name(number = 1)
      n_('Infrastructure Provider (Proxmox)', 'Infrastructure Providers (Proxmox)', number)
    end

    def self.catalog_types
      {"proxmox" => N_("Proxmox")}
    end

    def self.default_port
      8006
    end

    def self.params_for_create
      {
        :fields => [
          {
            :component => 'sub-form',
            :id        => 'endpoints-subform',
            :name      => 'endpoints-subform',
            :title     => _('Endpoints'),
            :fields    => [
              {
                :component              => 'validate-provider-credentials',
                :id                     => 'authentications.default.valid',
                :name                   => 'authentications.default.valid',
                :skipSubmit             => true,
                :isRequired             => true,
                :validationDependencies => %w[type zone_id],
                :fields                 => [
                  {
                    :component  => "text-field",
                    :id         => "endpoints.default.hostname",
                    :name       => "endpoints.default.hostname",
                    :label      => _("Hostname (or IPv4 or IPv6 address)"),
                    :isRequired => true,
                    :validate   => [{:type => "required"}],
                  },
                  {
                    :component    => "text-field",
                    :id           => "endpoints.default.port",
                    :name         => "endpoints.default.port",
                    :label        => _("API Port"),
                    :type         => "number",
                    :initialValue => default_port,
                    :isRequired   => true,
                    :validate     => [{:type => "required"}],
                  },
                  {
                    :component  => "text-field",
                    :id         => "authentications.default.userid",
                    :name       => "authentications.default.userid",
                    :label      => _("Username"),
                    :helperText => _("Should have privileged access, such as root@pam"),
                    :isRequired => true,
                    :validate   => [{:type => "required"}],
                  },
                  {
                    :component  => "password-field",
                    :id         => "authentications.default.password",
                    :name       => "authentications.default.password",
                    :label      => _("Password"),
                    :type       => "password",
                    :isRequired => true,
                    :validate   => [{:type => "required"}],
                  },
                ],
              },
            ],
          },
        ],
      }
    end

    def self.verify_credentials(args)
      _log.info("=== PROXMOX DEBUG: verify_credentials called ===")
      _log.info("Args received: #{args.inspect}")

      default_endpoint = args.dig("endpoints", "default")
      hostname, port = default_endpoint&.values_at("hostname", "port")

      authentication = args.dig("authentications", "default")
      userid, password = authentication&.values_at("userid", "password")

      port ||= default_port

      _log.info("Extracted values:")
      _log.info("  - hostname: #{hostname}")
      _log.info("  - port: #{port}")
      _log.info("  - userid: #{userid}")

      # Décrypter le mot de passe si nécessaire
      if password && password.start_with?("v2:")
        _log.info("Password is encrypted, decrypting...")
        password = ManageIQ::Password.decrypt(password)
        _log.info("Password decrypted successfully")
      end

      unless userid&.include?("@")
        _log.warn("Username does not contain realm, adding @pam")
        userid = "#{userid}@pam"
      end

      _log.info("Final userid with realm: #{userid}")

      result = raw_connect(hostname, port, userid, password)
      _log.info("Connection successful!")

      !!result
    rescue => err
      _log.error("=== PROXMOX ERROR in verify_credentials ===")
      _log.error("Error class: #{err.class}")
      _log.error("Error message: #{err.message}")
      _log.error("Backtrace: #{err.backtrace.first(10).join("\n")}")
      raise
    end

    def connect(options = {})
      raise MiqException::MiqHostError, _("No credentials defined") if missing_credentials?(options[:auth_type])

      username = authentication_userid(options[:auth_type])
      password = authentication_password(options[:auth_type])
      hostname = address
      port     = self.port || self.class.default_port

      unless username.include?("@")
        username = "#{username}@pam"
      end

      connection_data = self.class.raw_connect(hostname, port, username, password)
      ProxmoxClient.new(connection_data)
    end

    def verify_credentials(auth_type = nil, options = {})
      begin
        connect(options.merge(:auth_type => auth_type))
      rescue => err
        raise MiqException::MiqInvalidCredentialsError, err.message
      end

      true
    end

    def self.raw_connect(hostname, port, username, password, verify_ssl = false)
      _log.info("=== PROXMOX raw_connect ===")
      _log.info("Connecting to: https://#{hostname}:#{port}")
      _log.info("Username: #{username}")
      _log.info("Verify SSL: #{verify_ssl}")

      require 'rest-client'
      require 'json'
      require 'uri'

      url = "https://#{hostname}:#{port}/api2/json"

      _log.info("Attempting authentication...")

      auth_response = RestClient::Request.execute(
        method: :post,
        url: "#{url}/access/ticket",
        payload: URI.encode_www_form({
          username: username,
          password: password
        }),
        headers: {
          content_type: 'application/x-www-form-urlencoded'
        },
        verify_ssl: verify_ssl,
        timeout: 30,
        open_timeout: 10
      )

      _log.info("Auth response status: #{auth_response.code}")

      auth_data = JSON.parse(auth_response.body)

      unless auth_data['data'] && auth_data['data']['ticket']
        _log.error("Invalid response from Proxmox: #{auth_data.inspect}")
        raise MiqException::MiqInvalidCredentialsError, "No ticket received from Proxmox"
      end

      _log.info("Authentication successful!")

      {
        url:        url,
        ticket:     auth_data['data']['ticket'],
        csrf_token: auth_data['data']['CSRFPreventionToken'],
        verify_ssl: verify_ssl
      }
    rescue RestClient::Unauthorized => err
      _log.error("Authentication failed (401 Unauthorized)")
      _log.error("Response body: #{err.response&.body || 'N/A'}")
      raise MiqException::MiqInvalidCredentialsError,
            _("Login failed due to a bad username or password.")
    rescue RestClient::Exception => err
      _log.error("RestClient error: #{err.class} - #{err.message}")
      _log.error("Response code: #{err.response&.code || 'N/A'}")
      _log.error("Response body: #{err.response&.body || 'N/A'}")
      raise MiqException::MiqInvalidCredentialsError,
            _("Login failed: %{error}") % {:error => err.message}
    rescue => err
      _log.error("Unexpected error: #{err.class} - #{err.message}")
      _log.error("Backtrace: #{err.backtrace.first(5).join("\n")}")
      raise MiqException::MiqHostError,
            _("Unable to connect: %{error}") % {:error => err.message}
    end

    # Classe client Proxmox
    class ProxmoxClient
      attr_reader :url, :ticket, :csrf_token, :verify_ssl

      def initialize(connection_data)
        @url = connection_data[:url]
        @ticket = connection_data[:ticket]
        @csrf_token = connection_data[:csrf_token]
        @verify_ssl = connection_data[:verify_ssl]
      end

      def get(path)
        require 'rest-client'
        require 'json'

        # Enlever le slash initial si présent
        path = path.sub(/^\//, '')

        response = RestClient::Request.execute(
          method: :get,
          url: "#{@url}/#{path}",
          headers: {
            'Cookie' => "PVEAuthCookie=#{@ticket}"
          },
          verify_ssl: @verify_ssl,
          timeout: 60
        )

        result = JSON.parse(response.body)
        result['data']
      rescue RestClient::Exception => err
        ManageIQ::Providers::Proxmox::InfraManager._log.error("API call failed for #{path}: #{err.message}")
        raise
      end

      def post(path, payload = {})
        require 'rest-client'
        require 'json'

        path = path.sub(/^\//, '')

        response = RestClient::Request.execute(
          method: :post,
          url: "#{@url}/#{path}",
          payload: payload,
          headers: {
            'Cookie' => "PVEAuthCookie=#{@ticket}",
            'CSRFPreventionToken' => @csrf_token
          },
          verify_ssl: @verify_ssl,
          timeout: 60
        )

        result = JSON.parse(response.body)
        result['data']
      rescue RestClient::Exception => err
        ManageIQ::Providers::Proxmox::InfraManager._log.error("API POST failed for #{path}: #{err.message}")
        raise
      end

      def nodes
        @nodes ||= NodesCollection.new(self)
      end

      def cluster
        @cluster ||= ClusterCollection.new(self)
      end

      class ClusterCollection
        def initialize(client)
          @client = client
        end

        def resources
          @client.get('cluster/resources')
        end

        def status
          @client.get('cluster/status')
        end
      end

      class NodesCollection
        def initialize(client)
          @client = client
        end

        def all
          @client.get('nodes')
        end

        def get(node_name)
          Node.new(@client, node_name)
        end
      end

      class Node
        def initialize(client, name)
          @client = client
          @name = name
        end

        def qemu
          QemuCollection.new(@client, @name)
        end

        def lxc
          LxcCollection.new(@client, @name)
        end

        def storage
          @client.get("nodes/#{@name}/storage")
        end

        def network
          @client.get("nodes/#{@name}/network")
        end
      end

      class QemuCollection
        def initialize(client, node_name)
          @client = client
          @node_name = node_name
        end

        def all
          @client.get("nodes/#{@node_name}/qemu")
        end

        def get(vmid)
          @client.get("nodes/#{@node_name}/qemu/#{vmid}/config")
        end
      end

      class LxcCollection
        def initialize(client, node_name)
          @client = client
          @node_name = node_name
        end

        def all
          @client.get("nodes/#{@node_name}/lxc")
        end

        def get(vmid)
          @client.get("nodes/#{@node_name}/lxc/#{vmid}/config")
        end
      end
    end
  end
end
