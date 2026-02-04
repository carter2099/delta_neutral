class CreatePositions < ActiveRecord::Migration[8.1]
  def change
    create_table :positions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :nft_id, null: false
      t.string :network, null: false, default: "ethereum"
      t.string :pool_address
      t.string :token0_address
      t.string :token1_address
      t.string :token0_symbol
      t.string :token1_symbol
      t.integer :token0_decimals
      t.integer :token1_decimals
      t.integer :tick_lower
      t.integer :tick_upper
      t.string :liquidity
      t.decimal :token0_amount, precision: 40, scale: 18
      t.decimal :token1_amount, precision: 40, scale: 18
      t.decimal :current_tick
      t.decimal :token0_price_usd, precision: 20, scale: 8
      t.decimal :token1_price_usd, precision: 20, scale: 8
      t.decimal :initial_token0_value_usd, precision: 20, scale: 2
      t.decimal :initial_token1_value_usd, precision: 20, scale: 2
      t.boolean :active, default: true, null: false
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :positions, [:user_id, :nft_id, :network], unique: true
    add_index :positions, :active
  end
end
