class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.integer  :market_id
      t.string   :type
      t.float    :price
      t.float    :amount
      t.float    :total
      t.string   :state
      t.timestamps null: false
    end
  end
end
