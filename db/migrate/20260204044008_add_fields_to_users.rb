class AddFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :wallet_address, :string
    add_column :users, :paper_trading_mode, :boolean, default: true, null: false
    add_column :users, :testnet_mode, :boolean, default: true, null: false
    add_column :users, :auto_rebalance_enabled, :boolean, default: false, null: false
    add_column :users, :notification_email, :string
  end
end
