class HedgeAnalysisJob < ApplicationJob
  queue_as :default

  def perform(position_id)
    position = Position.find(position_id)
    return unless position.active?

    user = position.user
    config = position.hedge_configuration
    return unless config

    # First sync hedge positions
    HedgeSyncJob.perform_now(position_id)

    # Analyze delta drift
    analyzer = Hedging::DeltaAnalyzer.new
    result = analyzer.analyze(position)

    if result.needs_rebalance
      Rails.logger.info "[HedgeAnalysisJob] Position #{position_id} needs rebalance: #{result.reason}"

      # Send notification
      HedgeMailer.rebalance_alert(position, result).deliver_later if user.notification_email.present?

      # Auto-rebalance if enabled
      if config.auto_rebalance && user.auto_rebalance_enabled?
        Rails.logger.info "[HedgeAnalysisJob] Auto-rebalancing position #{position_id}"
        RebalanceExecutionJob.perform_later(position_id, "scheduled")
      end
    else
      Rails.logger.debug "[HedgeAnalysisJob] Position #{position_id} within threshold: #{result.reason}"
    end
  rescue => e
    Rails.logger.error "[HedgeAnalysisJob] Error analyzing position #{position_id}: #{e.message}"
    raise
  end
end
