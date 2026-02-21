class AddStatusAndMessageToShortRebalances < ActiveRecord::Migration[8.0]
  def change
    add_column :short_rebalances, :status, :string, default: "success", null: false
    add_column :short_rebalances, :message, :text
  end
end
