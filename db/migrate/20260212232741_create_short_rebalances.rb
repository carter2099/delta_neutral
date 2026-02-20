class CreateShortRebalances < ActiveRecord::Migration[8.1]
  def change
    create_table :short_rebalances do |t|
      t.references :hedge, null: false, foreign_key: true
      t.string :asset
      t.decimal :old_short_size, precision: 20, scale: 8
      t.decimal :new_short_size, precision: 20, scale: 8
      t.decimal :realized_pnl, precision: 20, scale: 8
      t.datetime :rebalanced_at

      t.timestamps
    end
  end
end
