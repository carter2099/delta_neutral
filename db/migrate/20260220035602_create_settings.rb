class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :hyperliquid_leverage, null: false, default: 3
      t.boolean :hyperliquid_cross_margin, null: false, default: true

      t.timestamps
    end
  end
end
