# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runners::Kubernetes::NodeAvailability, type: :service do
  let(:node) { Fabricate(:node_kubernetes) }
  let(:kubernetes_client) { double(KubernetesClient) }

  before do
    allow(node).to receive(:kubernetes_client).and_return(kubernetes_client)
  end

  it "fetches api info" do
    expect(kubernetes_client).to receive(:api_info)

    subject.perform(node: node)
  end
end
