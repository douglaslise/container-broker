class MonitorUnresponsiveNodeJob < ApplicationJob
  queue_as :default

  def perform(node:)
    Docker.info(node.docker_connection)
    node.available!
    node.update(last_error: nil)
    RunTasksJob.perform_later
  rescue StandardError => e
    node.register_error(e.message)
    Rails.logger.info("Node #{node} still unresponsive")
  end
end
