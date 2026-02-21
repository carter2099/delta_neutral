# Represents a delta-neutral short hedge attached to a {Position}.
#
# A hedge targets a short exposure of +target+ × pool amount for each asset.
# If the actual short deviates by more than +tolerance+ × target short, a
# rebalance is required. Each rebalance is recorded as a {ShortRebalance}.
#
# Each asset's short may live on the Hyperliquid main account or a subaccount.
# The +asset0_hl_account+ and +asset1_hl_account+ columns store the subaccount
# address; +nil+ means the short lives on the main account.
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

  # Returns the Hyperliquid account address assigned for the given asset index.
  #
  # @param asset_index [Integer] 0 or 1
  # @return [String, nil] subaccount address, or +nil+ for the main account
  def hl_account_for(asset_index)
    case asset_index
    when 0 then asset0_hl_account
    when 1 then asset1_hl_account
    end
  end

  # Checks if any active hedge already uses the main account for the given HL asset.
  #
  # @param hl_asset [String] the Hyperliquid trading symbol (e.g. +"ETH"+)
  # @param exclude_hedge [Hedge, nil] hedge to exclude from the check
  # @return [Boolean]
  def self.asset_account_in_use?(hl_asset, exclude_hedge: nil)
    scope = active.joins(:position).where(
      "(positions.asset0 IN (?) AND hedges.asset0_hl_account IS NULL) OR " \
      "(positions.asset1 IN (?) AND hedges.asset1_hl_account IS NULL)",
      symbols_for(hl_asset), symbols_for(hl_asset)
    )
    scope = scope.where.not(id: exclude_hedge.id) if exclude_hedge
    scope.exists?
  end

  # Checks if any active hedge uses the given subaccount for the given HL asset.
  #
  # @param subaccount_address [String] the subaccount address
  # @param hl_asset [String] the Hyperliquid trading symbol
  # @param exclude_hedge [Hedge, nil] hedge to exclude from the check
  # @return [Boolean]
  def self.subaccount_in_use_for?(subaccount_address, hl_asset, exclude_hedge: nil)
    scope = active.joins(:position).where(
      "(positions.asset0 IN (?) AND hedges.asset0_hl_account = ?) OR " \
      "(positions.asset1 IN (?) AND hedges.asset1_hl_account = ?)",
      symbols_for(hl_asset), subaccount_address,
      symbols_for(hl_asset), subaccount_address
    )
    scope = scope.where.not(id: exclude_hedge.id) if exclude_hedge
    scope.exists?
  end

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

  # Returns all Uniswap symbols that map to the given HL asset.
  #
  # @param hl_asset [String] e.g. +"ETH"+
  # @return [Array<String>] e.g. +["ETH", "WETH"]+
  def self.symbols_for(hl_asset)
    syms = [ hl_asset ]
    HyperliquidService::SYMBOL_MAP.each { |k, v| syms << k if v == hl_asset }
    syms
  end
  private_class_method :symbols_for
end
