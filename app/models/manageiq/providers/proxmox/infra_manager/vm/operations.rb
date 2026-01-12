module ManageIQ::Providers::Proxmox::InfraManager::Vm::Operations
  extend ActiveSupport::Concern
  include Operations::Snapshot

  included do
    supports(:terminate) { unsupported_reason(:control) }
  end
end

