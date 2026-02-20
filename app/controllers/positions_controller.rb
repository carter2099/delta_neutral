# Manages the current user's DeFi positions.
#
# All queries are scoped to {Current.user} to prevent cross-user data access.
class PositionsController < ApplicationController
  # GET /positions
  #
  # Lists all active positions for the current user, eager-loading the
  # associated DEX and hedge records.
  #
  # @return [void]
  def index
    @positions = Current.user.positions.active.includes(:dex, :hedge)
  end

  # GET /positions/:id
  #
  # Displays a single position along with its most recent 50 P&L snapshots
  # and full rebalance history.
  #
  # @return [void]
  def show
    @position = Current.user.positions.find(params[:id])
    @pnl_snapshots = @position.pnl_snapshots.order(captured_at: :desc).limit(50)
    @rebalances = @position.hedge&.short_rebalances&.order(rebalanced_at: :desc) || ShortRebalance.none
  end

  # POST /positions/:id/sync_now
  #
  # Enqueues a {PositionSyncJob} for the given position and redirects back
  # to the position detail page.
  #
  # @return [void]
  def sync_now
    @position = Current.user.positions.find(params[:id])
    PositionSyncJob.perform_later(@position.id)
    redirect_to position_path(@position), notice: "Position sync queued."
  end
end
