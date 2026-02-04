class HedgeConfigurationsController < ApplicationController
  before_action :require_authentication
  before_action :set_position
  before_action :set_hedge_configuration

  def show
    @available_perps = fetch_available_perps
  end

  def edit
    @available_perps = fetch_available_perps
  end

  def update
    if @hedge_configuration.update(hedge_configuration_params)
      redirect_to position_path(@position), notice: "Hedge configuration updated."
    else
      @available_perps = fetch_available_perps
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_position
    @position = current_user.positions.find(params[:position_id])
  end

  def set_hedge_configuration
    @hedge_configuration = @position.hedge_configuration || @position.create_hedge_configuration!
  end

  def hedge_configuration_params
    params.require(:hedge_configuration).permit(
      :hedge_ratio,
      :rebalance_threshold,
      :auto_rebalance,
      token_mappings: {}
    )
  end

  def fetch_available_perps
    client = Hyperliquid::ClientWrapper.new(testnet: current_user.testnet?)
    client.available_markets.map { |m| m[:name] }
  rescue => e
    Rails.logger.error "Failed to fetch HL markets: #{e.message}"
    HedgeConfiguration::DEFAULT_MAPPINGS.values.compact.uniq
  end
end
