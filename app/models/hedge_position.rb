class HedgePosition < ApplicationRecord
  belongs_to :position

  validates :asset, presence: true
  validates :size, presence: true, numericality: true
  validates :asset, uniqueness: { scope: :position_id }

  scope :shorts, -> { where("size < 0") }
  scope :longs, -> { where("size > 0") }

  def short?
    size.negative?
  end

  def long?
    size.positive?
  end

  def notional_value
    return 0 unless size && current_price
    size.abs * current_price
  end

  def pnl_percent
    return 0 unless entry_price && current_price && entry_price != 0

    if short?
      # For shorts: profit when price goes down
      ((entry_price - current_price) / entry_price) * 100
    else
      # For longs: profit when price goes up
      ((current_price - entry_price) / entry_price) * 100
    end
  end

  def stale?
    return true unless last_synced_at
    last_synced_at < 5.minutes.ago
  end
end
