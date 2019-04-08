class AddFastTradeToRegulates < ActiveRecord::Migration
  def change
    add_column :regulates, :fast_profit, :float
    add_column :regulates, :fast_trade, :boolean, default: false
  end
end
