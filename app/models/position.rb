class Position < ApplicationRecord
  belongs_to :user
  has_one :hedge_configuration, dependent: :destroy
  has_many :hedge_positions, dependent: :destroy
  has_many :rebalance_events, dependent: :destroy
  has_many :realized_pnls, dependent: :destroy

  validates :nft_id, presence: true
  validates :network, presence: true, inclusion: { in: %w[ethereum arbitrum] }
  validates :nft_id, uniqueness: { scope: [:user_id, :network] }

  scope :active, -> { where(active: true) }

  after_create :create_default_hedge_configuration

  NETWORKS = {
    "ethereum" => {
      subgraph_url: "https://gateway.thegraph.com/api/subgraphs/id/5zvR82QoaXYFyDEKLZ9t6v9adgnptxYpKpSbxtgVENFV",
      chain_id: 1
    },
    "arbitrum" => {
      subgraph_url: "https://gateway.thegraph.com/api/subgraphs/id/FbCGRftH4a3yZugY7TnbYgPJVEv2LvMT6oF1fxPe9aJM",
      chain_id: 42161
    }
  }.freeze

  def subgraph_url
    NETWORKS.dig(network, :subgraph_url)
  end

  def current_token0_value_usd
    return 0 unless token0_amount && token0_price_usd
    token0_amount * token0_price_usd
  end

  def current_token1_value_usd
    return 0 unless token1_amount && token1_price_usd
    token1_amount * token1_price_usd
  end

  def total_value_usd
    current_token0_value_usd + current_token1_value_usd
  end

  def initial_value_usd
    (initial_token0_value_usd || 0) + (initial_token1_value_usd || 0)
  end

  def lp_delta_usd
    total_value_usd - initial_value_usd
  end

  def total_realized_pnl
    realized_pnls.sum(:realized_pnl)
  end

  def in_range?
    return false unless current_tick && tick_lower && tick_upper
    current_tick >= tick_lower && current_tick <= tick_upper
  end

  private

  def create_default_hedge_configuration
    create_hedge_configuration! unless hedge_configuration
  end
end
