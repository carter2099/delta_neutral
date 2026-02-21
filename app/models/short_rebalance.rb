# Records a single hedge rebalancing event for a {Hedge}.
#
# Created by {HedgeSyncJob} whenever a short position is adjusted. Stores
# the before and after sizes and the realized P&L captured from Hyperliquid
# fill data at the time of the rebalance.
class ShortRebalance < ApplicationRecord
  STATUS_SUCCESS = "success"
  STATUS_FAILED = "failed"

  belongs_to :hedge

  scope :failed, -> { where(status: STATUS_FAILED) }
end
