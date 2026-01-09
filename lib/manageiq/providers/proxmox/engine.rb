module ManageIQ
  module Providers
    module Proxmox
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::Proxmox

        config.autoload_paths << root.join('lib').to_s

        def self.vmdb_plugin?
          true
        end

        def self.plugin_name
          _('Proxmox Provider')
        end

        def self.init_loggers
          $proxmox_log ||= Vmdb::Loggers.create_logger("proxmox.log")
        end

        def self.apply_logger_config(config)
          Vmdb::Loggers.apply_config_value(config, $proxmox_log, :level_proxmox)
        end

      end
    end
  end
end
