class CreateRebalanceEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :rebalance_events do |t|
      t.references :position, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :trigger_type, null: false
      t.json :pre_state, default: {}
      t.json :post_state, default: {}
      t.json :intended_actions, default: []
      t.json :executed_actions, default: []
      t.text :error_message
      t.boolean :paper_trade, default: false, null: false
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :rebalance_events, :status
    add_index :rebalance_events, :created_at
  end
end
