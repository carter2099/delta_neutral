class AddFeeColumnsToPnlSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :pnl_snapshots, :collected_fees0, :decimal, precision: 30, scale: 18
    add_column :pnl_snapshots, :collected_fees1, :decimal, precision: 30, scale: 18
    add_column :pnl_snapshots, :uncollected_fees0, :decimal, precision: 30, scale: 18
    add_column :pnl_snapshots, :uncollected_fees1, :decimal, precision: 30, scale: 18
  end
end
