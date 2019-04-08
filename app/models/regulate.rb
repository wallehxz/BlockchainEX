# == Schema Information
#
# Table name: regulates
#
# t.integer  "market_id"
# t.float    "amplitude"
# t.float    "retain"
# t.float    "cost"
# t.boolean  "notify_wx"
# t.boolean  "notify_sms"
# t.boolean  "notify_dd"
# t.datetime "created_at",                  null: false
# t.datetime "updated_at",                  null: false
# t.integer  "precision"
# t.integer  "fast_profit"
# t.boolean  "fast_trade",  default: false
#

class Regulate < ActiveRecord::Base
  validates_uniqueness_of :market_id
  belongs_to :market

  self.per_page = 10
end
