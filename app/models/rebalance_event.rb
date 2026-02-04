class RebalanceEvent < ApplicationRecord
  belongs_to :position
  has_many :realized_pnls, dependent: :nullify

  validates :status, presence: true, inclusion: { in: %w[pending executing completed failed] }
  validates :trigger_type, presence: true, inclusion: { in: %w[manual scheduled threshold] }

  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :pending, -> { where(status: "pending") }

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def mark_executing!
    update!(status: "executing", started_at: Time.current)
  end

  def mark_completed!(executed_actions: [], post_state: {})
    update!(
      status: "completed",
      completed_at: Time.current,
      executed_actions: executed_actions,
      post_state: post_state
    )
  end

  def mark_failed!(error_message)
    update!(
      status: "failed",
      completed_at: Time.current,
      error_message: error_message
    )
  end

  def actions_summary
    if paper_trade?
      "Paper trade: #{intended_actions.size} action(s)"
    else
      "Executed #{executed_actions.size} action(s)"
    end
  end
end
