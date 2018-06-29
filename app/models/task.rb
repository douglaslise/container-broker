class Task
  include GlobalID::Identification
  include Mongoid::Document
  include Mongoid::Uuid
  include MongoidEnumerable

  field :name, type: String
  field :container_id, type: String # do not remove - needed for update status after completion
  field :image, type: String
  field :cmd, type: String
  field :storage_mount, type: String
  enumerable :status, %w(waiting starting started running retry error completed)
  field :exit_code, type: Integer
  field :error, type: String
  field :error_log, type: String
  field :created_at, type: DateTime
  field :started_at, type: DateTime
  field :finished_at, type: DateTime
  field :progress, type: String
  field :try_count, type: Integer, default: 0

  belongs_to :slot, optional: true

  before_create {|task| task.created_at = Time.zone.now }
  after_create { RunTasksJob.perform_later }

  validates :name, :image, :cmd, presence: true

  def set_error_log(log)
    self.error_log = BSON::Binary.new(log, :generic)
  end

  def mark_as_started(container_id:, slot:)
    update!(container_id: container_id, slot: slot, started_at: Time.zone.now)
    started!
  end

  def retry
    if self.try_count < Settings.task_retry_count
      update(try_count: self.try_count + 1)
      retry!
    else
      error!
    end
  end

  def seconds_running
    finished_at.sec - started_at.sec if completed?
  end

  def force_retry!
    update(try_count: 0)
    starting!
  end
end
