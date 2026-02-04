class CreateHedgeConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :hedge_configurations do |t|
      t.references :position, null: false, foreign_key: true, index: { unique: true }
      t.decimal :hedge_ratio, precision: 5, scale: 4, default: 1.0, null: false
      t.decimal :rebalance_threshold, precision: 5, scale: 4, default: 0.05, null: false
      t.boolean :auto_rebalance, default: false, null: false
      t.json :token_mappings, default: {}

      t.timestamps
    end
  end
end
