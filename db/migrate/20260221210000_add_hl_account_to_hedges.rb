class AddHlAccountToHedges < ActiveRecord::Migration[8.1]
  def change
    add_column :hedges, :asset0_hl_account, :string
    add_column :hedges, :asset1_hl_account, :string
  end
end
