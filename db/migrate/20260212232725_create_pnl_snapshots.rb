class CreatePnlSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :pnl_snapshots do |t|
      t.references :position, null: false, foreign_key: true
      t.datetime :captured_at
      t.decimal :asset0_amount, precision: 30, scale: 18
      t.decimal :asset1_amount, precision: 30, scale: 18
      t.decimal :asset0_price_usd, precision: 20, scale: 8
      t.decimal :asset1_price_usd, precision: 20, scale: 8
      t.decimal :hedge_unrealized, precision: 20, scale: 8
      t.decimal :hedge_realized, precision: 20, scale: 8

      t.timestamps
    end
  end
end
