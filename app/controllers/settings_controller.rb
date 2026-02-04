class SettingsController < ApplicationController
  before_action :require_authentication

  def show
    @user = current_user
    @circuit_breaker = Hedging::CircuitBreaker.new(cache_key: "hedging:circuit:#{current_user.id}")
  end

  def update
    @user = current_user

    if @user.update(user_params)
      redirect_to settings_path, notice: "Settings updated."
    else
      @circuit_breaker = Hedging::CircuitBreaker.new(cache_key: "hedging:circuit:#{current_user.id}")
      render :show, status: :unprocessable_entity
    end
  end

  def reset_circuit_breaker
    circuit_breaker = Hedging::CircuitBreaker.new(cache_key: "hedging:circuit:#{current_user.id}")
    circuit_breaker.reset!
    redirect_to settings_path, notice: "Circuit breaker reset."
  end

  private

  def user_params
    params.require(:user).permit(
      :wallet_address,
      :paper_trading_mode,
      :testnet_mode,
      :auto_rebalance_enabled,
      :notification_email
    )
  end
end
