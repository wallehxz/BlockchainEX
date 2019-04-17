class AddRangeTradeToOrders < ActiveRecord::Migration
  def change
    add_column :regulates, :range_trade, :boolean, default: false
    add_column :regulates, :range_cash,  :float
    add_column :regulates, :range_profit, :float
  end
end
