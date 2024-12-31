# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20210725091532) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string   "exchange"
    t.string   "currency"
    t.float    "balance"
    t.float    "freezing"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "side",       default: ""
    t.float    "total"
  end

  create_table "candles", force: :cascade do |t|
    t.integer  "market_id"
    t.float    "o"
    t.float    "h"
    t.float    "l"
    t.float    "c"
    t.float    "v"
    t.string   "t"
    t.datetime "ts"
  end

  create_table "indicators", force: :cascade do |t|
    t.integer  "market_id"
    t.string   "name"
    t.datetime "created_at"
  end

  create_table "markets", force: :cascade do |t|
    t.integer  "sequence"
    t.string   "base_unit"
    t.string   "quote_unit"
    t.string   "source"
    t.string   "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "messages", force: :cascade do |t|
    t.integer  "market_id"
    t.text     "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "orders", force: :cascade do |t|
    t.integer  "market_id"
    t.string   "type"
    t.float    "price"
    t.float    "amount"
    t.float    "total"
    t.string   "state"
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
    t.string   "cause"
    t.string   "category",   default: "limit"
    t.string   "position"
  end

  create_table "regulates", force: :cascade do |t|
    t.integer  "market_id"
    t.float    "amplitude"
    t.float    "retain"
    t.float    "cost"
    t.boolean  "notify_wx"
    t.boolean  "notify_sms"
    t.boolean  "notify_dd"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.float    "fast_profit"
    t.boolean  "fast_trade",       default: false
    t.float    "support"
    t.float    "resistance"
    t.float    "fast_cash"
    t.boolean  "range_trade",      default: false
    t.float    "range_cash"
    t.float    "range_profit"
    t.integer  "amount_precision"
    t.integer  "price_precision"
    t.float    "cash_profit"
    t.boolean  "stoploss",         default: false
    t.boolean  "takeprofit",       default: false
    t.boolean  "chasedown",        default: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.integer  "role",                   default: 1
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

end
