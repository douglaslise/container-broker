# frozen_string_literal: true

module Runners
  module Docker
    class UpdateNodeStatus
      def perform(node:)
        Rails.logger.debug("Start updating node status for #{node}")

        # Other tasks can be started at this time. Because of this it's necessary to load the tasks first and then the containers
        started_tasks = Task.started.where(:slot.in => node.slots.pluck(:id)).to_a

        containers = ::Docker::Container.all({ all: true }, node.docker_connection)

        Rails.logger.debug("Got #{containers.count} containers")

        containers.each do |container|
          container_names = extract_names(container: container)

          slot = node.slots.find_by(:runner_id.in => container_names)
          if slot
            runner_id = slot.runner_id

            Rails.logger.debug("Slot found for container #{runner_id}: #{slot}")

            if container.info["State"] == "exited"
              Rails.logger.debug("Container #{runner_id} exited")
              if slot.running?
                slot.releasing!
                Rails.logger.debug("Slot was running. Marked as releasing. Slot: #{slot}. Current task: #{slot.current_task}")
                ReleaseSlotJob.perform_later(slot: MongoidSerializableModel.new(slot), runner_id: runner_id)
              else
                Rails.logger.debug("Slot was not running (it was #{slot.status}). Ignoring.")
              end
            elsif started_with_error?(container: container, docker_connection: node.docker_connection)
              container.start
            end
          else
            Rails.logger.debug("Slot not found for container #{container_names}")

            if (Settings.ignore_containers & container_names).none?
              # It is needed to select the container using just any of its names
              RemoveContainerJob.perform_later(node: node, runner_id: container_names.first)
            else
              Rails.logger.debug("Container #{container_names.join(",")} is ignored for removal")
            end
          end
        end

        all_container_names = containers.flat_map {|container| extract_names(container: container) }

        RescheduleTasksForMissingContainers
          .new(runner_ids: all_container_names, started_tasks: started_tasks)
          .perform

        node.update_last_success
      rescue Excon::Error, ::Docker::Error::DockerError => e
        node.register_error(e.message)
      end

      private

      def started_with_error?(container:, docker_connection:)
        container.info["State"] == "created" && ::Docker::Container.get(container.id, docker_connection).info["State"]["ExitCode"].positive?
      end

      def extract_names(container:)
        container.info["Names"].map do |name|
          name.remove(%r{^/})
        end
      end
    end
  end
end
