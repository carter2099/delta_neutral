class RealizedPnl < ApplicationRecord
  belongs_to :position
  belongs_to :rebalance_event, optional: true

  validates :asset, presence: true
  validates :size_closed, presence: true, numericality: true
  validates :entry_price, presence: true, numericality: { greater_than: 0 }
  validates :exit_price, presence: true, numericality: { greater_than: 0 }
  validates :realized_pnl, presence: true, numericality: true

  scope :recent, -> { order(created_at: :desc) }
  scope :profitable, -> { where("realized_pnl > 0") }
  scope :losing, -> { where("realized_pnl < 0") }

  def profitable?
    realized_pnl.positive?
  end

  def pnl_percent
    return 0 unless entry_price && exit_price && entry_price != 0

    # For shorts (negative size_closed): profit when price goes down
    if size_closed.negative?
      ((entry_price - exit_price) / entry_price) * 100
    else
      ((exit_price - entry_price) / entry_price) * 100
    end
  end

  def net_pnl
    realized_pnl - (fees || 0)
  end
end
