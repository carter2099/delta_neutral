# Represents a delta-neutral short hedge attached to a {Position}.
#
# A hedge targets a short exposure of +target+ × pool amount for each asset.
# If the actual short deviates by more than +tolerance+ × target short, a
# rebalance is required. Each rebalance is recorded as a {ShortRebalance}.
class Hedge < ApplicationRecord
  belongs_to :position

  has_many :short_rebalances, dependent: :destroy

  validates :target, :tolerance, presence: true
  validates :target, numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :tolerance, numericality: { greater_than: 0, less_than_or_equal_to: 1 }

  # @!scope class
  # @!method active
  #   Returns only hedges that are currently active.
  #   @return [ActiveRecord::Relation<Hedge>]
  scope :active, -> { where(active: true) }

  # Determines whether a rebalance is needed for a given asset.
  #
  # A rebalance is triggered when the absolute difference between the target
  # short and the current short exceeds +tolerance+ × target short.
  #
  # @param pool_amount [BigDecimal] current token amount in the liquidity pool
  # @param current_short [BigDecimal] current short position size on the exchange
  # @return [Boolean] +true+ if the deviation exceeds the tolerance threshold
  def needs_rebalance?(pool_amount, current_short)
    target_short = pool_amount * target
    (target_short - current_short).abs > (target_short * tolerance)
  end
end
