# Provides CRUD management for hedges and on-demand sync.
#
# All hedge lookups are scoped through the current user's positions to
# prevent unauthorized access.
class HedgesController < ApplicationController
  # GET /hedges
  #
  # Lists all hedges belonging to the current user's positions.
  #
  # @return [void]
  def index
    @hedges = Hedge.joins(:position).where(positions: { user_id: Current.user.id }).includes(:position, :short_rebalances)
  end

  # GET /hedges/:id
  #
  # Shows a single hedge and its rebalance history in descending order.
  #
  # @return [void]
  def show
    @hedge = find_hedge
    @rebalances = @hedge.short_rebalances.order(rebalanced_at: :desc)
  end

  # GET /hedges/new
  #
  # Renders the new-hedge form, optionally pre-selecting a position via
  # the +position_id+ query parameter.
  #
  # @return [void]
  def new
    @hedge = Hedge.new
    @unhedged_positions = unhedged_positions
    @selected_position = Current.user.positions.find_by(id: params[:position_id]) if params[:position_id]
  end

  # POST /hedges
  #
  # Creates a hedge after verifying the target position belongs to the
  # current user.
  #
  # @return [void]
  def create
    @hedge = Hedge.new(hedge_params)

    # Verify the position belongs to the current user
    position = Current.user.positions.find_by(id: @hedge.position_id)
    unless position
      @unhedged_positions = unhedged_positions
      flash.now[:alert] = "Invalid position."
      render :new, status: :unprocessable_entity
      return
    end

    if @hedge.save
      redirect_to hedge_path(@hedge), notice: "Hedge created successfully."
    else
      @unhedged_positions = unhedged_positions
      render :new, status: :unprocessable_entity
    end
  end

  # GET /hedges/:id/edit
  #
  # Renders the edit form for a hedge belonging to the current user.
  #
  # @return [void]
  def edit
    @hedge = find_hedge
  end

  # PATCH /hedges/:id
  #
  # Updates hedge attributes and redirects to the hedge detail page on success.
  #
  # @return [void]
  def update
    @hedge = find_hedge

    if @hedge.update(hedge_params)
      redirect_to hedge_path(@hedge), notice: "Hedge updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /hedges/:id
  #
  # Destroys the hedge and redirects to the hedges index.
  #
  # @return [void]
  def destroy
    @hedge = find_hedge

    begin
      hyperliquid = HyperliquidService.new
      position = @hedge.position
      [ position.asset0, position.asset1 ].each do |asset|
        hl_asset = HedgeSyncJob::HYPERLIQUID_SYMBOL_MAP.fetch(asset, asset)
        hyperliquid.close_short(asset: hl_asset)
      end
    rescue => e
      Rails.logger.error("[HedgesController] Failed to close shorts for hedge #{@hedge.id}: #{e.message}")
      redirect_to hedge_path(@hedge), alert: "Failed to close Hyperliquid shorts: #{e.message}"
      return
    end

    @hedge.destroy
    redirect_to hedges_path, notice: "Hedge removed."
  end

  # POST /hedges/:id/sync_now
  #
  # Enqueues a {HedgeSyncJob} for the given hedge and redirects to the
  # hedge detail page.
  #
  # @return [void]
  def sync_now
    @hedge = find_hedge
    HedgeSyncJob.perform_later(@hedge.id)
    redirect_to hedge_path(@hedge), notice: "Hedge sync queued."
  end

  private

  # Finds a hedge owned by the current user, raising {ActiveRecord::RecordNotFound}
  # if it does not exist or belongs to another user.
  #
  # @return [Hedge]
  def find_hedge
    Hedge.joins(:position).where(positions: { user_id: Current.user.id }).find(params[:id])
  end

  # Returns the permitted parameters for creating or updating a hedge.
  #
  # @return [ActionController::Parameters]
  def hedge_params
    params.require(:hedge).permit(:position_id, :target, :tolerance, :active)
  end

  # Returns active positions that do not yet have a hedge.
  #
  # @return [ActiveRecord::Relation<Position>]
  def unhedged_positions
    Current.user.positions.active.left_joins(:hedge).where(hedges: { id: nil })
  end
end
