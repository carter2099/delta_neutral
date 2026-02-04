class HedgeConfiguration < ApplicationRecord
  belongs_to :position

  validates :hedge_ratio, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 2 }
  validates :rebalance_threshold, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 1 }

  # Common token mappings from LP tokens to HL perpetual symbols
  DEFAULT_MAPPINGS = {
    "WETH" => "ETH",
    "WBTC" => "BTC",
    "ARB" => "ARB",
    "LINK" => "LINK",
    "UNI" => "UNI",
    "AAVE" => "AAVE",
    "CRV" => "CRV",
    "LDO" => "LDO",
    "GMX" => "GMX",
    "PENDLE" => "PENDLE",
    # Stablecoins - nil means don't hedge
    "USDC" => nil,
    "USDT" => nil,
    "DAI" => nil,
    "FRAX" => nil
  }.freeze

  def mapping_for(token_symbol)
    return nil unless token_symbol
    token_mappings.fetch(token_symbol.upcase) { DEFAULT_MAPPINGS[token_symbol.upcase] }
  end

  def should_hedge?(token_symbol)
    mapping_for(token_symbol).present?
  end

  def set_mapping(token_symbol, hl_symbol)
    self.token_mappings = token_mappings.merge(token_symbol.upcase => hl_symbol)
  end

  def target_hedge_for(token_symbol, token_amount)
    hl_symbol = mapping_for(token_symbol)
    return nil unless hl_symbol

    # Negative size means short position
    target_size = -(token_amount * hedge_ratio)
    { asset: hl_symbol, size: target_size }
  end
end
