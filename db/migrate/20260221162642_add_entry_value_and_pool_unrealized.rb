class AddEntryValueAndPoolUnrealized < ActiveRecord::Migration[8.1]
  def up
    add_column :positions, :entry_value_usd, :decimal, precision: 20, scale: 8
    add_column :pnl_snapshots, :pool_unrealized, :decimal, precision: 20, scale: 8

    # Backfill existing positions: set entry_value_usd from their earliest snapshot
    execute <<~SQL
      UPDATE positions
      SET entry_value_usd = (
        SELECT (s.asset0_amount * s.asset0_price_usd) + (s.asset1_amount * s.asset1_price_usd)
        FROM pnl_snapshots s
        WHERE s.position_id = positions.id
        ORDER BY s.captured_at ASC
        LIMIT 1
      )
      WHERE entry_value_usd IS NULL
        AND EXISTS (SELECT 1 FROM pnl_snapshots WHERE position_id = positions.id)
    SQL
  end

  def down
    remove_column :positions, :entry_value_usd
    remove_column :pnl_snapshots, :pool_unrealized
  end
end
