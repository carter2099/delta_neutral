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

ActiveRecord::Schema[8.1].define(version: 2026_02_12_232741) do
  create_table "dexes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_dexes_on_name", unique: true
  end

  create_table "hedges", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "position_id", null: false
    t.decimal "target", precision: 5, scale: 4, null: false
    t.decimal "tolerance", precision: 5, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["position_id"], name: "index_hedges_on_position_id", unique: true
  end

  create_table "networks", force: :cascade do |t|
    t.integer "chain_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["chain_id"], name: "index_networks_on_chain_id", unique: true
    t.index ["name"], name: "index_networks_on_name", unique: true
  end

  create_table "pnl_snapshots", force: :cascade do |t|
    t.decimal "asset0_amount", precision: 30, scale: 18
    t.decimal "asset0_price_usd", precision: 20, scale: 8
    t.decimal "asset1_amount", precision: 30, scale: 18
    t.decimal "asset1_price_usd", precision: 20, scale: 8
    t.datetime "captured_at"
    t.datetime "created_at", null: false
    t.decimal "hedge_realized", precision: 20, scale: 8
    t.decimal "hedge_unrealized", precision: 20, scale: 8
    t.integer "position_id", null: false
    t.datetime "updated_at", null: false
    t.index ["position_id"], name: "index_pnl_snapshots_on_position_id"
  end

  create_table "positions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "asset0"
    t.decimal "asset0_amount", precision: 30, scale: 18
    t.decimal "asset0_price_usd", precision: 20, scale: 8
    t.string "asset1"
    t.decimal "asset1_amount", precision: 30, scale: 18
    t.decimal "asset1_price_usd", precision: 20, scale: 8
    t.datetime "created_at", null: false
    t.integer "dex_id", null: false
    t.string "external_id"
    t.string "pool_address"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "wallet_id", null: false
    t.index ["dex_id"], name: "index_positions_on_dex_id"
    t.index ["external_id"], name: "index_positions_on_external_id"
    t.index ["user_id"], name: "index_positions_on_user_id"
    t.index ["wallet_id"], name: "index_positions_on_wallet_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "short_rebalances", force: :cascade do |t|
    t.string "asset"
    t.datetime "created_at", null: false
    t.integer "hedge_id", null: false
    t.decimal "new_short_size", precision: 20, scale: 8
    t.decimal "old_short_size", precision: 20, scale: 8
    t.decimal "realized_pnl", precision: 20, scale: 8
    t.datetime "rebalanced_at"
    t.datetime "updated_at", null: false
    t.index ["hedge_id"], name: "index_short_rebalances_on_hedge_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "wallets", force: :cascade do |t|
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.integer "network_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["network_id"], name: "index_wallets_on_network_id"
    t.index ["user_id"], name: "index_wallets_on_user_id"
  end

  add_foreign_key "hedges", "positions"
  add_foreign_key "pnl_snapshots", "positions"
  add_foreign_key "positions", "dexes"
  add_foreign_key "positions", "users"
  add_foreign_key "positions", "wallets"
  add_foreign_key "sessions", "users"
  add_foreign_key "short_rebalances", "hedges"
  add_foreign_key "wallets", "networks"
  add_foreign_key "wallets", "users"
end
