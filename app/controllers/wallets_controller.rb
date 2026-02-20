# Manages blockchain wallets for the current user.
#
# All queries are scoped to {Current.user} to prevent cross-user access.
class WalletsController < ApplicationController
  # GET /wallets
  #
  # Lists all wallets belonging to the current user, eager-loading the
  # associated network and positions.
  #
  # @return [void]
  def index
    @wallets = Current.user.wallets.includes(:network, :positions)
  end

  # GET /wallets/new
  #
  # Renders the new-wallet form with all available networks.
  #
  # @return [void]
  def new
    @wallet = Current.user.wallets.build
    @networks = Network.all
  end

  # POST /wallets
  #
  # Creates a wallet scoped to the current user. Re-renders the form on
  # validation failure.
  #
  # @return [void]
  def create
    @wallet = Current.user.wallets.build(wallet_params)

    if @wallet.save
      redirect_to wallets_path, notice: "Wallet added successfully."
    else
      @networks = Network.all
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /wallets/:id
  #
  # Destroys the wallet and all its associated positions, then redirects
  # to the wallets index.
  #
  # @return [void]
  def destroy
    @wallet = Current.user.wallets.find(params[:id])
    @wallet.destroy
    redirect_to wallets_path, notice: "Wallet removed."
  end

  # POST /wallets/:id/sync_now
  #
  # Enqueues a {WalletSyncJob} for the given wallet and redirects to the
  # wallets index.
  #
  # @return [void]
  def sync_now
    @wallet = Current.user.wallets.find(params[:id])
    WalletSyncJob.perform_later(@wallet.id)
    redirect_to wallets_path, notice: "Wallet sync queued."
  end

  private

  # Returns the permitted parameters for creating a wallet.
  #
  # @return [ActionController::Parameters]
  def wallet_params
    params.require(:wallet).permit(:network_id, :address)
  end
end
