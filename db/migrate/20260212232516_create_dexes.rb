class CreateDexes < ActiveRecord::Migration[8.1]
  def change
    create_table :dexes do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :dexes, :name, unique: true
  end
end
