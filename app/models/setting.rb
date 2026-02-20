# Stores per-user Hyperliquid trading preferences (leverage and margin mode).
class Setting < ApplicationRecord
  belongs_to :user

  validates :hyperliquid_leverage, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 50 }
  validates :hyperliquid_cross_margin, inclusion: { in: [ true, false ] }
end
