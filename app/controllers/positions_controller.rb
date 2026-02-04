class PositionsController < ApplicationController
  before_action :require_authentication
  before_action :set_position, only: [:show, :edit, :update, :destroy, :rebalance, :sync]

  def index
    @positions = current_user.positions.includes(:hedge_configuration, :hedge_positions).order(created_at: :desc)
  end

  def show
    @hedge_config = @position.hedge_configuration
    @hedge_positions = @position.hedge_positions
    @rebalance_events = @position.rebalance_events.recent.limit(10)
    @realized_pnls = @position.realized_pnls.recent.limit(10)

    # Calculate analysis
    analyzer = Hedging::DeltaAnalyzer.new
    @analysis = analyzer.analyze(@position)

    calculator = Hedging::Calculator.new
    @target_hedges = calculator.calculate_targets(@position)
    @adjustments = calculator.calculate_adjustments(@position)
  end

  def new
    @position = current_user.positions.build(network: "ethereum")
  end

  def create
    @position = current_user.positions.build(position_params)

    if @position.save
      # Trigger initial sync
      PositionSyncJob.perform_later(@position.id)
      redirect_to @position, notice: "Position added. Syncing data..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @position.update(position_params)
      redirect_to @position, notice: "Position updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @position.update!(active: false)
    redirect_to positions_path, notice: "Position deactivated."
  end

  def rebalance
    RebalanceExecutionJob.perform_later(@position.id, "manual")
    redirect_to @position, notice: "Rebalance initiated. Check back for results."
  end

  def sync
    PositionSyncJob.perform_later(@position.id)
    redirect_to @position, notice: "Sync initiated."
  end

  private

  def set_position
    @position = current_user.positions.find(params[:id])
  end

  def position_params
    params.require(:position).permit(:nft_id, :network, :active)
  end
end
