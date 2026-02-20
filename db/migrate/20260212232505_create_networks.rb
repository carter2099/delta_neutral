class CreateNetworks < ActiveRecord::Migration[8.1]
  def change
    create_table :networks do |t|
      t.string :name, null: false
      t.integer :chain_id, null: false

      t.timestamps
    end
    add_index :networks, :name, unique: true
    add_index :networks, :chain_id, unique: true
  end
end
