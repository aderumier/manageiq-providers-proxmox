module ManageIQ::Providers
  module Proxmox
    class Inventory < ManageIQ::Providers::Inventory
      require_relative 'inventory/collector'
      require_relative 'inventory/parser'
      require_relative 'inventory/persister'

      attr_reader :collector, :parser, :persister

      def initialize(manager)
        @manager = manager
      end

      def refresh
        collector_klass = collector_class
        parser_klass = parser_class
        persister_klass = persister_class

        collector = collector_klass.new(@manager)
        parser = parser_klass.new
        persister = persister_klass.new(@manager)

        parser.collector = collector
        parser.persister = persister

        parser.parse

        persister.persist!
      end

      private

      def collector_class
        ManageIQ::Providers::Proxmox::Inventory::Collector
      end

      def parser_class
        ManageIQ::Providers::Proxmox::Inventory::Parser
      end

      def persister_class
        ManageIQ::Providers::Proxmox::Inventory::Persister
      end
    end
  end
end
