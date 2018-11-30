class CreateCandles < ActiveRecord::Migration
  def change
    create_table :candles do |t|
      t.integer :market_id
      t.float   :o
      t.float   :h
      t.float   :l
      t.float   :c
      t.float   :v
      t.string  :t
      t.datetime :ts
    end
  end
end
