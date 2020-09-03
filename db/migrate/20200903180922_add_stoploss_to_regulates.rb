class AddStoplossToRegulates < ActiveRecord::Migration
  def change
    add_column :regulates, :stoploss, :boolean, default: false
    add_column :regulates, :takeprofit, :boolean, default: false
  end
end
