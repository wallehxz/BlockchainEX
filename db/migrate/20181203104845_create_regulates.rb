class CreateRegulates < ActiveRecord::Migration
  def change
    create_table :regulates do |t|
      t.integer  :market_id
      t.float    :amplitude
      t.float    :retain
      t.float    :cost
      t.boolean  :notify_wx
      t.boolean  :notify_sms
      t.boolean  :notify_dd
      t.timestamps null: false
    end
  end
end
