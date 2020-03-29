class AddCashProfitToRegulates < ActiveRecord::Migration
  def change
    add_column :regulates, :cash_profit, :float
  end
end
