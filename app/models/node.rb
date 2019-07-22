class Node
  include Mongoid::Document
  include Mongoid::Uuid
  include GlobalID::Identification
  include MongoidEnumerable

  field :name, type: String
  field :hostname, type: String
  field :cores, type: Integer, default: 0
  field :memory, type: Integer, default: 0
  field :available, type: Boolean, default: true
  field :usage_percent, type: Integer
  field :last_error, type: String
  field :last_success_at, type: DateTime
  enumerable :status, %w(available unstable unavailable), default: "unavailable", after_change: :status_change

  has_many :slots

  def available_slot_with_execution_type(execution_type)
    available_slots.to_a.find{|slot| slot.execution_type == execution_type }
  end

  def available_slots
    slots.idle
  end

  def available_slots
    slots.idle
  end

  def populate(slot_execution_type_groups)
    destroy_slots if slots

    slot_execution_type_groups.each do |slot_execution_type_group|
      slot_execution_type_group[:amount].times do
        Slot.create!(execution_type: slot_execution_type_group[:execution_type], node: self)
      end
    end

    FriendlyNameNodes.new.call
  end

  def destroy_slots
    slots.destroy_all
  end

  def docker_connection
    Docker.logger = Logger.new(STDOUT)
    Docker::Connection.new(hostname, {connect_timeout: 10, read_timeout: 10, write_timeout: 10})
  end

  def update_usage
    usage = (1.0 - available_slots.count.to_f / slots.count) * 100
    update!(usage_percent: usage)
  end

  def register_error(error)
    update!(last_error: error)
    if last_success_at && last_success_at < Settings.node_unavailable_after_seconds.seconds.ago
      unavailable!
      MigrateTasksFromDeadNodeJob.perform_later(node: self)
    else
      unstable!
    end
  end

  def update_last_success
    update!(last_success_at: Time.zone.now)
  end
end
