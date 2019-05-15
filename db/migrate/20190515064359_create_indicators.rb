class CreateIndicators < ActiveRecord::Migration
  def change
    create_table :indicators do |t|
      t.integer  :market_id
      t.string   :name
      t.datetime :created_at
    end
  end
end
