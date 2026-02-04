class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    @positions = current_user.positions.active.includes(:hedge_configuration, :hedge_positions)
    @recent_events = RebalanceEvent.joins(:position)
                                   .where(positions: { user_id: current_user.id })
                                   .recent
                                   .limit(5)

    # Calculate portfolio summary
    @total_lp_value = @positions.sum(&:total_value_usd)
    @total_hedge_value = @positions.flat_map(&:hedge_positions).sum { |hp| hp.notional_value }
    @total_unrealized_pnl = @positions.flat_map(&:hedge_positions).sum { |hp| hp.unrealized_pnl || 0 }
    @total_realized_pnl = @positions.sum(&:total_realized_pnl)

    # Check for positions needing rebalance
    analyzer = Hedging::DeltaAnalyzer.new
    @positions_needing_rebalance = @positions.select do |pos|
      analyzer.analyze(pos).needs_rebalance
    end
  end
end
