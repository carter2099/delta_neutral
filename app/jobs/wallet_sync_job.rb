# Syncs Uniswap liquidity positions for one or all wallets.
#
# When called with a +wallet_id+, only that wallet is synced. When called
# without arguments, every wallet in the database is synced. Positions no
# longer found in the subgraph are marked inactive; new positions are
# created and existing ones are updated.
#
# @example Sync a single wallet
#   WalletSyncJob.perform_later(wallet.id)
#
# @example Sync all wallets (used by the recurring scheduler)
#   WalletSyncJob.perform_later
class WalletSyncJob < ApplicationJob
  queue_as :default

  # Performs the wallet sync.
  #
  # @param wallet_id [Integer, nil] ID of the wallet to sync, or +nil+ to
  #   sync all wallets
  # @return [void]
  def perform(wallet_id = nil)
    Rails.logger.debug { "[WalletSyncJob] starting — wallet_id=#{wallet_id || 'all'}" }
    wallets = wallet_id ? Wallet.where(id: wallet_id) : Wallet.all
    uniswap = UniswapService.new
    uniswap_dex = Dex.find_by!(name: "uniswap")

    Rails.logger.debug { "[WalletSyncJob] found #{wallets.count} wallet(s) to sync" }

    wallets.find_each do |wallet|
      sync_wallet(wallet, uniswap, uniswap_dex)
    rescue => e
      Rails.logger.error("WalletSyncJob failed for wallet #{wallet.id}: #{e.message}")
    end

    Rails.logger.debug { "[WalletSyncJob] complete" }
  end

  private

  # Syncs positions for a single wallet from the Uniswap subgraph.
  #
  # Marks positions absent from the subgraph response as inactive, then
  # upserts all positions returned by the subgraph.
  #
  # @param wallet [Wallet] the wallet to sync
  # @param uniswap [UniswapService] configured Uniswap subgraph client
  # @param uniswap_dex [Dex] the Uniswap {Dex} record
  # @return [void]
  def sync_wallet(wallet, uniswap, uniswap_dex)
    Rails.logger.debug { "[WalletSyncJob] syncing wallet #{wallet.id} (#{wallet.address})" }
    subgraph_positions = uniswap.fetch_positions(wallet.address)
    Rails.logger.debug { "[WalletSyncJob] wallet #{wallet.id}: subgraph returned #{subgraph_positions.size} position(s)" }
    external_ids = subgraph_positions.map { |p| p[:external_id] }

    # Mark positions not in subgraph as inactive
    wallet.positions.active.where.not(external_id: external_ids).update_all(active: false)

    subgraph_positions.each do |pos_data|
      position = wallet.positions.find_or_initialize_by(external_id: pos_data[:external_id])
      action = position.new_record? ? "creating" : "updating"
      Rails.logger.debug { "[WalletSyncJob] #{action} position #{pos_data[:external_id]} (#{pos_data[:asset0]}/#{pos_data[:asset1]})" }
      position.assign_attributes(
        user: wallet.user,
        dex: uniswap_dex,
        asset0: pos_data[:asset0],
        asset1: pos_data[:asset1],
        asset0_amount: pos_data[:asset0_amount],
        asset1_amount: pos_data[:asset1_amount],
        pool_address: pos_data[:pool_address],
        active: true
      )
      position.save!
    end

    Rails.logger.debug { "[WalletSyncJob] wallet #{wallet.id} sync complete" }
  end
end
