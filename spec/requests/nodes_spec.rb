require 'rails_helper'

RSpec.describe "Nodes", type: :request do
  describe "POST /node" do
    it "creates a new node" do
      post nodes_path, params: { node: { hostname: "host1.test" } }

      expect(response).to be_created
    end

    it "returns the newly created node" do
      post nodes_path, params: { node: { hostname: "host1.test" } }

      expect(json_response).to include_json(hostname: "host1.test")
      expect(json_response).to match(hash_including("uuid"))
    end
  end

  describe "GET /nodes" do
    let!(:node1) { Fabricate(:node, hostname: "node1.test") }
    let!(:node2) { Fabricate(:node, hostname: "node2.test") }

    it "gets all nodes" do
      get nodes_path

      expect(json_response).to match_array(
        [
          hash_including("uuid" => node1.uuid, "hostname" => node1.hostname),
          hash_including("uuid" => node2.uuid, "hostname" => node2.hostname)
        ]
      )
    end
  end

  describe "PATCH /nodes/:uuid" do
    let!(:node) { Fabricate(:node, hostname: "node1.test") }
    let(:new_hostname) { "node2.test" }

    it "returns ok" do
      patch node_path(node.uuid), params: {node: {hostname: new_hostname}}

      expect(response).to be_ok
    end

    it "update the node" do
      patch node_path(node.uuid), params: {node: {hostname: new_hostname}}

      node.reload
      expect(node.hostname).to eq(new_hostname)
    end
  end

  context "POST /nodes/:uuid/accept_new_tasks" do
    let!(:node) { Fabricate(:node, accept_new_tasks: false) }

    subject { post accept_new_tasks_node_path(node.uuid); node.reload }

    it "gets paused" do
      expect { subject }.to change(node, :accept_new_tasks?).from(false).to(true)
    end
  end

  context "POST /nodes/:uuid/reject_new_tasks" do
    let!(:node) { Fabricate(:node, accept_new_tasks: true) }

    subject { post reject_new_tasks_node_path(node.uuid); node.reload }

    it "gets paused" do
      expect { subject }.to change(node, :accept_new_tasks?).from(true).to(false)
    end
  end

  context "POST /nodes/:uuid/kill_containers" do
    let!(:node) { Fabricate(:node, accept_new_tasks: true) }

    let(:kill_containers_service) { double("KillNodeContainers") }

    before do
      allow(KillNodeContainers).to receive(:new).with(node: node).and_return(kill_containers_service)
    end

    it "kills all node containers" do
      expect(kill_containers_service).to receive(:perform)

      post kill_containers_node_path(node.uuid)
    end
  end
end
