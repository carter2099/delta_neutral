class CreatePositions < ActiveRecord::Migration[8.1]
  def change
    create_table :positions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :dex, null: false, foreign_key: true
      t.references :wallet, null: false, foreign_key: true
      t.string :asset0
      t.string :asset1
      t.decimal :asset0_amount, precision: 30, scale: 18
      t.decimal :asset1_amount, precision: 30, scale: 18
      t.decimal :asset0_price_usd, precision: 20, scale: 8
      t.decimal :asset1_price_usd, precision: 20, scale: 8
      t.string :external_id
      t.string :pool_address
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    add_index :positions, :external_id
  end
end
