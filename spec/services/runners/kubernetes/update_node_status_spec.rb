# frozen_string_literal: true

require "rails_helper"

RSpec.describe Runners::Kubernetes::UpdateNodeStatus, type: :service do
  let(:node) { Fabricate(:node_kubernetes) }
  let(:slot_status) { :running }
  let!(:slot) { Fabricate(:slot, status: slot_status, container_id: "job_name", node: node) }
  let(:succeeded) { nil }
  let(:failed) { nil }
  let(:kubernetes_client) { double(KubernetesClient) }
  let(:jobs_status) do
    {
      "job_name" => Kubeclient::Resource.new(succeeded: succeeded, failed: failed),
      "job_name_2" => Kubeclient::Resource.new(succeeded: succeeded, failed: failed)
    }
  end

  before do
    allow(node).to receive(:kubernetes_client).and_return(kubernetes_client)
    allow(kubernetes_client).to receive(:fetch_jobs_status).and_return(jobs_status)
  end

  it "updates node last success" do
    expect(node).to receive(:update_last_success)

    subject.perform(node: node)
  end

  context "when Kubeclient raises an HTTP error" do
    before do
      allow(kubernetes_client).to receive(:fetch_jobs_status).and_raise(Kubeclient::HttpError.new(nil, "error_message", nil))
    end

    it "registers error" do
      expect(node).to receive(:register_error).with("error_message")

      subject.perform(node: node)
    end
  end

  context "when SocketError is raised" do
    before do
      allow(kubernetes_client).to receive(:fetch_jobs_status).and_raise(SocketError.new("error_message_socket"))
    end

    it "registers error" do
      expect(node).to receive(:register_error).with("error_message_socket")

      subject.perform(node: node)
    end
  end

  context "when job is not completed" do
    let(:succeeded) { nil }
    let(:failed) { nil }

    it "does not release slot" do
      expect(ReleaseSlotJob).not_to receive(:perform_later)
        .with(hash_including(container_id: "job_name"))

      subject.perform(node: node)
    end
  end

  context "when job is succeeded" do
    let(:succeeded) { 1 }

    context "and slot is running" do
      it "releases slot" do
        expect { subject.perform(node: node) }.to change { slot.reload.status }.from("running").to("releasing")
      end

      it "performs ReleaseSlotJob" do
        expect(ReleaseSlotJob).to receive(:perform_later)
          .with(hash_including(container_id: "job_name"))

        subject.perform(node: node)
      end
    end

    context "and slot is not running" do
      let(:slot_status) { :idle }

      it "does not release slot" do
        expect { subject.perform(node: node) }.to_not(change { slot.reload.status })
      end
    end
  end

  context "when job is failed" do
    let(:failed) { 1 }

    context "and slot is running" do
      it "releases slot" do
        expect { subject.perform(node: node) }.to change { slot.reload.status }.from("running").to("releasing")
      end

      it "performs ReleaseSlotJob" do
        expect(ReleaseSlotJob).to receive(:perform_later)
          .with(hash_including(container_id: "job_name"))

        subject.perform(node: node)
      end
    end

    context "and slot is not running" do
      let(:slot_status) { :idle }

      it "does not release slot" do
        expect { subject.perform(node: node) }.to_not(change { slot.reload.status })
      end
    end
  end
end
