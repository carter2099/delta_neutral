class CreateHedges < ActiveRecord::Migration[8.1]
  def change
    create_table :hedges do |t|
      t.references :position, null: false, foreign_key: true, index: { unique: true }
      t.decimal :target, precision: 5, scale: 4, null: false
      t.decimal :tolerance, precision: 5, scale: 4, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
