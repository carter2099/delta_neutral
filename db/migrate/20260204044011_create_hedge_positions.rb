class CreateHedgePositions < ActiveRecord::Migration[8.1]
  def change
    create_table :hedge_positions do |t|
      t.references :position, null: false, foreign_key: true
      t.string :asset, null: false
      t.decimal :size, precision: 20, scale: 8, null: false
      t.decimal :entry_price, precision: 20, scale: 8
      t.decimal :current_price, precision: 20, scale: 8
      t.decimal :unrealized_pnl, precision: 20, scale: 8
      t.decimal :liquidation_price, precision: 20, scale: 8
      t.decimal :margin_used, precision: 20, scale: 8
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :hedge_positions, [:position_id, :asset], unique: true
  end
end
