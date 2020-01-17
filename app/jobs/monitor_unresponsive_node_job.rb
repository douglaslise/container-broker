# frozen_string_literal: true

class MonitorUnresponsiveNodeJob < ApplicationJob
  queue_as :default

  def perform(node:)
    Runners::ServicesFactory.fabricate(node: node, service: :monitor_unresponsive_node).perform
  end
end
