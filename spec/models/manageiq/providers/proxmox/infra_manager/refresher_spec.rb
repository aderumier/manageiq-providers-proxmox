describe ManageIQ::Providers::Proxmox::InfraManager::Refresher do
  include Spec::Support::EmsRefreshHelper

  let(:ems) { FactoryBot.create(:ems_proxmox_with_vcr_authentication) }

  describe ".refresh" do
    it "performs a full refresh" do
      with_vcr do
        described_class.refresh([ems])
      end
    end
  end
end
