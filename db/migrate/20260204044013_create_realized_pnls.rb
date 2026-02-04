class CreateRealizedPnls < ActiveRecord::Migration[8.1]
  def change
    create_table :realized_pnls do |t|
      t.references :position, null: false, foreign_key: true
      t.references :rebalance_event, foreign_key: true
      t.string :asset, null: false
      t.decimal :size_closed, precision: 20, scale: 8, null: false
      t.decimal :entry_price, precision: 20, scale: 8, null: false
      t.decimal :exit_price, precision: 20, scale: 8, null: false
      t.decimal :realized_pnl, precision: 20, scale: 8, null: false
      t.decimal :fees, precision: 20, scale: 8, default: 0

      t.timestamps
    end

    add_index :realized_pnls, :created_at
  end
end
