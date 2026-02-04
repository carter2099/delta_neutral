# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_04_044013) do
  create_table "hedge_configurations", force: :cascade do |t|
    t.boolean "auto_rebalance", default: false, null: false
    t.datetime "created_at", null: false
    t.decimal "hedge_ratio", precision: 5, scale: 4, default: "1.0", null: false
    t.integer "position_id", null: false
    t.decimal "rebalance_threshold", precision: 5, scale: 4, default: "0.05", null: false
    t.json "token_mappings", default: {}
    t.datetime "updated_at", null: false
    t.index ["position_id"], name: "index_hedge_configurations_on_position_id", unique: true
  end

  create_table "hedge_positions", force: :cascade do |t|
    t.string "asset", null: false
    t.datetime "created_at", null: false
    t.decimal "current_price", precision: 20, scale: 8
    t.decimal "entry_price", precision: 20, scale: 8
    t.datetime "last_synced_at"
    t.decimal "liquidation_price", precision: 20, scale: 8
    t.decimal "margin_used", precision: 20, scale: 8
    t.integer "position_id", null: false
    t.decimal "size", precision: 20, scale: 8, null: false
    t.decimal "unrealized_pnl", precision: 20, scale: 8
    t.datetime "updated_at", null: false
    t.index ["position_id", "asset"], name: "index_hedge_positions_on_position_id_and_asset", unique: true
    t.index ["position_id"], name: "index_hedge_positions_on_position_id"
  end

  create_table "positions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.decimal "current_tick"
    t.decimal "initial_token0_value_usd", precision: 20, scale: 2
    t.decimal "initial_token1_value_usd", precision: 20, scale: 2
    t.datetime "last_synced_at"
    t.string "liquidity"
    t.string "network", default: "ethereum", null: false
    t.string "nft_id", null: false
    t.string "pool_address"
    t.integer "tick_lower"
    t.integer "tick_upper"
    t.string "token0_address"
    t.decimal "token0_amount", precision: 40, scale: 18
    t.integer "token0_decimals"
    t.decimal "token0_price_usd", precision: 20, scale: 8
    t.string "token0_symbol"
    t.string "token1_address"
    t.decimal "token1_amount", precision: 40, scale: 18
    t.integer "token1_decimals"
    t.decimal "token1_price_usd", precision: 20, scale: 8
    t.string "token1_symbol"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["active"], name: "index_positions_on_active"
    t.index ["user_id", "nft_id", "network"], name: "index_positions_on_user_id_and_nft_id_and_network", unique: true
    t.index ["user_id"], name: "index_positions_on_user_id"
  end

  create_table "realized_pnls", force: :cascade do |t|
    t.string "asset", null: false
    t.datetime "created_at", null: false
    t.decimal "entry_price", precision: 20, scale: 8, null: false
    t.decimal "exit_price", precision: 20, scale: 8, null: false
    t.decimal "fees", precision: 20, scale: 8, default: "0.0"
    t.integer "position_id", null: false
    t.decimal "realized_pnl", precision: 20, scale: 8, null: false
    t.integer "rebalance_event_id"
    t.decimal "size_closed", precision: 20, scale: 8, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_realized_pnls_on_created_at"
    t.index ["position_id"], name: "index_realized_pnls_on_position_id"
    t.index ["rebalance_event_id"], name: "index_realized_pnls_on_rebalance_event_id"
  end

  create_table "rebalance_events", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.json "executed_actions", default: []
    t.json "intended_actions", default: []
    t.boolean "paper_trade", default: false, null: false
    t.integer "position_id", null: false
    t.json "post_state", default: {}
    t.json "pre_state", default: {}
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.string "trigger_type", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_rebalance_events_on_created_at"
    t.index ["position_id"], name: "index_rebalance_events_on_position_id"
    t.index ["status"], name: "index_rebalance_events_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "auto_rebalance_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "notification_email"
    t.boolean "paper_trading_mode", default: true, null: false
    t.string "password_digest", null: false
    t.boolean "testnet_mode", default: true, null: false
    t.datetime "updated_at", null: false
    t.string "wallet_address"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "hedge_configurations", "positions"
  add_foreign_key "hedge_positions", "positions"
  add_foreign_key "positions", "users"
  add_foreign_key "realized_pnls", "positions"
  add_foreign_key "realized_pnls", "rebalance_events"
  add_foreign_key "rebalance_events", "positions"
  add_foreign_key "sessions", "users"
end
