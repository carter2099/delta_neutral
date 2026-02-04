class PositionPollingSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    Position.active.find_each do |position|
      PositionSyncJob.perform_later(position.id)
    end
  end
end
