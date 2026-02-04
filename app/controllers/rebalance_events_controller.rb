class RebalanceEventsController < ApplicationController
  before_action :require_authentication

  def index
    @rebalance_events = RebalanceEvent
      .joins(:position)
      .where(positions: { user_id: current_user.id })
      .includes(:position)
      .recent
      .limit(50)
  end

  def show
    @rebalance_event = RebalanceEvent
      .joins(:position)
      .where(positions: { user_id: current_user.id })
      .find(params[:id])

    @position = @rebalance_event.position
    @realized_pnls = @rebalance_event.realized_pnls
  end
end
