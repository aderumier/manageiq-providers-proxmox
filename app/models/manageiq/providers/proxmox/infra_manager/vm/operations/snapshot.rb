module ManageIQ::Providers::Proxmox::InfraManager::Vm::Operations::Snapshot
  extend ActiveSupport::Concern

  included do
    supports :snapshots do
      unsupported_reason(:control) || ext_management_system.unsupported_reason(:snapshots)
    end

    supports :revert_to_snapshot do
      revert_unsupported_message unless allowed_to_revert?
    end

    supports_not :remove_all_snapshots, :reason => N_("Removing all snapshots is currently not supported")
  end

  def raw_create_snapshot(_name, desc, memory)
    with_provider_connection do |connection|
      snapshot_name = _name || "snapshot-#{Time.now.to_i}"
      
      params = {
        :snapname => snapshot_name
      }
      params[:description] = desc if desc
      params[:vmstate] = 1 if memory
      
      result = connection.post("nodes/#{location}/snapshot", params)
      
      # Proxmox returns a task ID (UPID) as a string that we need to wait for
      if result && result.is_a?(String) && !result.empty?
        connection.cluster.wait_for_task(result)
      end
      
      snapshot_name
    end
  end

  def raw_remove_snapshot(snapshot_id)
    snapshot = snapshots.find_by(:id => snapshot_id)
    raise _("Requested VM snapshot not found, unable to remove snapshot") unless snapshot
    
    with_provider_connection do |connection|
      result = connection.delete("nodes/#{location}/snapshot/#{snapshot.uid_ems}")
      
      # Proxmox returns a task ID (UPID) as a string that we need to wait for
      if result && result.is_a?(String) && !result.empty?
        connection.cluster.wait_for_task(result)
      end
      
      true
    end
  end

  def raw_revert_to_snapshot(snapshot_id)
    snapshot = snapshots.find_by(:id => snapshot_id)
    raise _("Requested VM snapshot not found, unable to revert to snapshot") unless snapshot
    
    with_provider_connection do |connection|
      result = connection.post("nodes/#{location}/snapshot/#{snapshot.uid_ems}/rollback", {})
      
      # Proxmox returns a task ID (UPID) as a string that we need to wait for
      if result && result.is_a?(String) && !result.empty?
        connection.cluster.wait_for_task(result)
      end
      
      true
    end
  end

  def snapshot_name_optional?
    true
  end

  def snapshot_description_required?
    false
  end

  def allowed_to_revert?
    current_state == 'off'
  end

  def revert_to_snapshot_denied_message(active = false)
    return revert_unsupported_message unless allowed_to_revert?
    return _("Revert is not allowed for a snapshot that is the active one") if active
  end

  def remove_snapshot_denied_message(active = false)
    return _("Delete is not allowed for a snapshot that is the active one") if active
  end

  def snapshotting_memory_allowed?
    current_state == 'on'
  end

  private

  def revert_unsupported_message
    _("Revert is allowed only when VM is down. Current state is %{state}") % {:state => current_state}
  end
end

