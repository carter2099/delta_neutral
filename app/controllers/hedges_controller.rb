# Provides CRUD management for hedges and on-demand sync.
#
# All hedge lookups are scoped through the current user's positions to
# prevent unauthorized access.
class HedgesController < ApplicationController
  # GET /hedges/:id
  #
  # Shows a single hedge and its rebalance history in descending order.
  #
  # @return [void]
  def show
    @hedge = find_hedge
    @rebalances = @hedge.short_rebalances.order(rebalanced_at: :desc).limit(10)

    position = @hedge.position

    begin
      hyperliquid = HyperliquidService.new
      @shorts = [ [ position.asset0, 0 ], [ position.asset1, 1 ] ].filter_map do |asset, idx|
        hl_asset = HyperliquidService.normalize_symbol(asset)
        account_address = @hedge.hl_account_for(idx)
        hyperliquid.get_position(hl_asset, address: account_address)
      end
    rescue => e
      Rails.logger.error("[HedgesController] Failed to fetch shorts for hedge #{@hedge.id}: #{e.message}")
      @shorts = []
      flash.now[:alert] = "Could not load Hyperliquid positions."
    end
    @asset_metrics = [ [ position.asset0, position.asset0_amount, 0 ], [ position.asset1, position.asset1_amount, 1 ] ].map do |asset, pool_amount, asset_index|
      hl_asset = HyperliquidService.normalize_symbol(asset)
      short_data = @shorts.find { |s| s[:asset] == hl_asset }
      current_short = short_data ? short_data[:size].abs : BigDecimal("0")
      sz_decimals = hyperliquid ? hyperliquid.sz_decimals(hl_asset) : 6
      target_short = (pool_amount * @hedge.target).floor(sz_decimals)

      if target_short > 0
        divergence = ((current_short - target_short) / target_short)
        rebalance_proximity = divergence.abs / @hedge.tolerance
      else
        divergence = BigDecimal("0")
        rebalance_proximity = BigDecimal("0")
      end

      {
        asset: asset,
        pool_amount: pool_amount,
        current_short: current_short,
        target_short: target_short,
        sz_decimals: sz_decimals,
        divergence: divergence,
        rebalance_proximity: rebalance_proximity,
        needs_rebalance: @hedge.needs_rebalance?(pool_amount, current_short)
      }
    end
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

    position = Current.user.positions.find_by(id: @hedge.position_id)
    unless position
      @unhedged_positions = unhedged_positions
      flash.now[:alert] = "Invalid position."
      render :new, status: :unprocessable_entity
      return
    end

    if @hedge.save
      HedgeSyncJob.perform_later(@hedge.id)
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
    position = @hedge.position

    begin
      hyperliquid = HyperliquidService.new
      before_close = Time.current
      [ [ position.asset0, 0 ], [ position.asset1, 1 ] ].each do |asset, idx|
        hl_asset = HyperliquidService.normalize_symbol(asset)
        vault_address = @hedge.hl_account_for(idx)
        hyperliquid.close_short(asset: hl_asset, vault_address: vault_address)

        # Withdraw USDC back to main if on a subaccount
        if vault_address
          balance = hyperliquid.account_balance(vault_address)
          if balance[:withdrawable] > 0
            hyperliquid.withdraw_from_subaccount(subaccount_address: vault_address, usd: balance[:withdrawable])
          end
        end
      end
    rescue => e
      Rails.logger.error("[HedgesController] Failed to close shorts for hedge #{@hedge.id}: #{e.message}")
      redirect_to hedge_path(@hedge), alert: "Failed to close Hyperliquid shorts: #{e.message}"
      return
    end

    # Capture closure PnL and bake total realized into the latest snapshot
    closure_pnl = [ [ position.asset0, 0 ], [ position.asset1, 1 ] ].sum do |asset, idx|
      hl_asset = HyperliquidService.normalize_symbol(asset)
      account_address = @hedge.hl_account_for(idx)
      fetch_realized_pnl(hyperliquid, hl_asset, before_close, address: account_address)
    end
    historical_pnl = @hedge.short_rebalances.sum(:realized_pnl)
    total_realized = historical_pnl + closure_pnl

    latest_snap = position.pnl_snapshots.order(captured_at: :desc).first
    if latest_snap
      latest_snap.update!(hedge_realized: total_realized, hedge_unrealized: 0)
    end

    @hedge.destroy
    redirect_to position_path(position), notice: "Hedge removed."
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

  def fetch_realized_pnl(hyperliquid, asset, since, address: nil)
    fills = hyperliquid.user_fills(start_time: since, address: address)
    fills
      .select { |f| f["coin"] == asset && f["closedPnl"].present? }
      .sum { |f| BigDecimal(f["closedPnl"]) }
  rescue => e
    Rails.logger.warn("Failed to fetch realized PnL from fills for #{asset}: #{e.message}")
    BigDecimal("0")
  end
end
