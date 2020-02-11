# frozen_string_literal: true

Fabricator(:slot) do
  node
  status "idle"
  execution_type "execution-type"
end

Fabricator(:slot_idle, from: :slot) do
  status "idle"
  runner_id nil
  execution_type "execution-type"
end

Fabricator(:slot_attaching, from: :slot) do
  status "attaching"
  runner_id nil
  execution_type "execution-type"
end

Fabricator(:slot_running, from: :slot) do
  status "running"
  runner_id { SecureRandom.hex }
  execution_type "execution-type"
end

Fabricator(:slot_releasing, from: :slot) do
  status "releasing"
  runner_id { SecureRandom.hex }
  execution_type "execution-type"
end
