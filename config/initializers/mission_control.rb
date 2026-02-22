MissionControl::Jobs.http_basic_auth_enabled = false
MissionControl::Jobs.base_controller_class = "ApplicationController"

# Sort failed/pending/in_progress jobs by most recent first (default is oldest first)
Rails.application.config.after_initialize do
  ActiveJob::QueueAdapters::SolidQueueExt::SolidQueueJobs.prepend(Module.new do
    private

    def order_executions(executions)
      if solid_queue_status.scheduled?
        executions.ordered
      else
        executions.order(job_id: :desc)
      end
    end
  end)
end
