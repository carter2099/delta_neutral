# Renders the main dashboard for the authenticated user.
#
# Aggregates portfolio-level data: active positions, total USD value,
# active hedge count, and the 10 most recent hedge rebalances.
class DashboardController < ApplicationController
  # GET /dashboard
  #
  # Loads summary data for the current user's portfolio.
  #
  # @return [void]
  def index
    @positions = Current.user.positions.active.includes(:dex, :hedge)
    @total_value = @positions.sum(&:total_value_usd)
    @active_hedges = @positions.count { |p| p.hedge&.active? }
    @recent_rebalances = ShortRebalance.joins(hedge: :position)
      .where(positions: { user_id: Current.user.id })
      .order(rebalanced_at: :desc)
      .limit(10)
  end
end
