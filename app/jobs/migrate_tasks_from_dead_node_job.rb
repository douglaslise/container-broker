# frozen_string_literal: true

class MigrateTasksFromDeadNodeJob < ApplicationJob
  queue_as :default

  def perform(node:)
    if node.available?
      Rails.logger.debug("Not migrating tasks because #{node} returned to available status")
      return
    end

    LockManager.new(type: self.class.to_s, id: node.id, wait: false, expire: 1.minute).lock do
      Rails.logger.debug("Migrating tasks from #{node}")
      node.slots.reject(&:idle?).each do |slot|
        Rails.logger.debug("Migrating task for #{slot}")
        current_task = slot.current_task
        if current_task
          Rails.logger.debug("Retrying slot current task #{current_task}")
          current_task.mark_as_retry if current_task.starting? || current_task.started?
        else
          Rails.logger.debug("Slot does not have current task")
        end

        Rails.logger.debug("Releasing #{slot}")
        slot.release
        Rails.logger.debug("#{slot} released")
      end
    end
  end
end
